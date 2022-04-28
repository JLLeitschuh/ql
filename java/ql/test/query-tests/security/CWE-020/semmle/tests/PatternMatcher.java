import java.util.regex.Pattern;

public class PatternMatcher {
    {
        test("<scrivbscript:pt>alert(1)</scrivbscript:pt>");
    }

    String test(String value) {
        Pattern p = Pattern.compile("javascript:", Pattern.CASE_INSENSITIVE);
        value = p.matcher(value).replaceAll("");
        Pattern.compile("vbscript:", Pattern.CASE_INSENSITIVE);
        return p.matcher(value).replaceAll("");
    }
}
