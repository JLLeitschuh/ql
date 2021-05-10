import ratpack.core.handling.Context;
import ratpack.core.http.TypedData;
import ratpack.core.form.Form;
import ratpack.core.form.UploadedFile;
import ratpack.core.parse.Parse;
import ratpack.exec.Promise;
import java.io.OutputStream;

class Resource {

    void sink(Object o) {}

    String taint() {
        return null;
    }

    void test1(Context ctx) {
        sink(ctx.getRequest().getContentLength()); //$hasTaintFlow
        sink(ctx.getRequest().getCookies()); //$hasTaintFlow
        sink(ctx.getRequest().oneCookie("Magic-Cookie")); //$hasTaintFlow
        sink(ctx.getRequest().getHeaders()); //$hasTaintFlow
        sink(ctx.getRequest().getHeaders().get("questionable_header")); //$hasTaintFlow
        sink(ctx.getRequest().getHeaders().getAll("questionable_header")); //$hasTaintFlow
        sink(ctx.getRequest().getHeaders().getNames()); //$hasTaintFlow
        sink(ctx.getRequest().getHeaders().asMultiValueMap()); //$hasTaintFlow
        sink(ctx.getRequest().getHeaders().asMultiValueMap().get("questionable_header")); //$hasTaintFlow
        sink(ctx.getRequest().getPath()); //$hasTaintFlow
        sink(ctx.getRequest().getQuery()); //$hasTaintFlow
        sink(ctx.getRequest().getQueryParams()); //$hasTaintFlow
        sink(ctx.getRequest().getQueryParams().get("questionable_parameter")); //$hasTaintFlow
        sink(ctx.getRequest().getRawUri()); //$hasTaintFlow
        sink(ctx.getRequest().getUri()); //$hasTaintFlow
    }

    void test2(Context ctx, OutputStream os) {
        ctx.getRequest().getBody().then(td -> {
            sink(td.getText()); //$hasTaintFlow
            sink(td.getBuffer()); //$hasTaintFlow
            sink(td.getBytes()); //$hasTaintFlow
            sink(td.getContentType()); //$hasTaintFlow
            sink(td.getInputStream()); //$hasTaintFlow
            sink(os);
            td.writeTo(os);
            sink(os); //$hasTaintFlow
            if (td instanceof UploadedFile) {
                UploadedFile uf = (UploadedFile) td;
                sink(uf.getFileName()); //$hasTaintFlow
            }
        });
    }

    void test3(Context ctx) {
        sink(ctx.getRequest().getBody().map(TypedData::getText)); //$hasTaintFlow
        ctx.getRequest().getBody().map(TypedData::getText).then(this::sink); //$hasTaintFlow
        ctx
            .getRequest()
            .getBody()
            .map(TypedData::getText)
            .next(this::sink) //$hasTaintFlow
            .then(this::sink); //$hasTaintFlow
    }

    void test4() {
        String tainted = taint();
        Promise.value(tainted);
        sink(Promise.value(tainted)); //$hasTaintFlow
        Promise
            .value(tainted)
            .flatMap(a -> Promise.value(a))
            .then(this::sink); //$hasTaintFlow
    }

    void test5(Context ctx) {
        ctx
            .getRequest()
            .getBody()
            .map(data -> {
                Form form = ctx.parse(data, Form.form());
                sink(form); //$hasTaintFlow
                return form;
            })
            .then(form -> {
                sink(form.file("questionable_file")); //$hasTaintFlow
                sink(form.file("questionable_file").getFileName()); //$hasTaintFlow
                sink(form.files("questionable_files")); //$hasTaintFlow
                sink(form.files()); //$hasTaintFlow
                sink(form.asMultimap()); //$hasTaintFlow
                sink(form.asMultimap().asMap()); //$hasTaintFlow
            });
    }

    void test6(Context ctx) {
        ctx
            .parse(Parse.of(Form.class))
            .then(form -> {
                sink(form); //$hasTaintFlow
            });
        ctx
            .parse(Form.class)
            .then(form -> {
                sink(form); //$hasTaintFlow
            });
    }
}