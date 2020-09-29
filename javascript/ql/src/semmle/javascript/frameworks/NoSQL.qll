/**
 * Provides classes for working with NoSQL libraries.
 */

import javascript

module NoSQL {
  /** An expression that is interpreted as a NoSQL query. */
  abstract class Query extends Expr {
    /** Gets an expression that is interpreted as a code operator in this query. */
    DataFlow::Node getACodeOperator() { none() }
  }
}

/**
 * Gets a value that has been assigned to the "$where" property of an object that flows to `queryArg`.
 */
private DataFlow::Node getADollarWhereProperty(API::Node queryArg) {
  result = queryArg.getMember("$where").getARhs()
}

/**
 * Provides classes modeling the MongoDB library.
 */
private module MongoDB {
  /**
   * Gets an access to `mongodb.MongoClient`.
   */
  private API::Node getAMongoClient() {
    result = API::moduleImport("mongodb").getMember("MongoClient")
    or
    // slightly imprecise, is not supposed to have a result if the parameter name is "db" (that would be a mongodb v2 `Db`).
    result = getAMongoDbCallback().getParameter(1)
  }

  /** Gets an api node that refers to a `connect` callback. */
  private API::Node getAMongoDbCallback() {
    result = getAMongoClient().getMember("connect").getLastParameter()
  }

  /**
   * Gets an API node that may refer to a MongoDB database connection.
   */
  private API::Node getAMongoDb() {
    result = getAMongoClient().getMember("db").getReturn()
    or
    // slightly imprecise, is not supposed to have a result if the parameter name is "client" (that would be a mongodb v3 `Mongoclient`).
    result = getAMongoDbCallback().getParameter(1)
  }

  /**
   * A collection based on the type `mongodb.Collection`.
   *
   * Note that this also covers `mongoose` models since they are subtypes
   * of `mongodb.Collection`.
   */
  private class TypedMongoCollection extends API::EntryPoint {
    TypedMongoCollection() { this = "TypedMongoCollection" }

    override DataFlow::SourceNode getAUse() { result.hasUnderlyingType("mongodb", "Collection") }

    override DataFlow::Node getARhs() { none() }
  }

  /** Gets a data flow node referring to a MongoDB collection. */
  private API::Node getACollection() {
    // A collection resulting from calling `Db.collection(...)`.
    exists(API::Node collection | collection = getAMongoDb().getMember("collection").getReturn() |
      result = collection
      or
      result = collection.getParameter(1).getParameter(0)
    )
    or
    result = any(TypedMongoCollection c).getNode()
  }

  /** A call to a MongoDB query method. */
  private class QueryCall extends DatabaseAccess, DataFlow::CallNode {
    int queryArgIdx;
    API::Node callee;

    QueryCall() {
      exists(string method |
        CollectionMethodSignatures::interpretsArgumentAsQuery(method, queryArgIdx) and
        callee = getACollection().getMember(method)
      ) and
      this = callee.getACall()
    }

    override DataFlow::Node getAQueryArgument() { result = getArgument(queryArgIdx) }

    DataFlow::Node getACodeOperator() {
      result = getADollarWhereProperty(callee.getParameter(queryArgIdx))
    }
  }

  /**
   * An expression that is interpreted as a MongoDB query.
   */
  class Query extends NoSQL::Query {
    QueryCall qc;

    Query() { this = qc.getAQueryArgument().asExpr() }

    override DataFlow::Node getACodeOperator() { result = qc.getACodeOperator() }
  }

  /**
   * Provides signatures for the Collection methods.
   */
  module CollectionMethodSignatures {
    /**
     * Holds if Collection method `name` interprets parameter `n` as a query.
     */
    predicate interpretsArgumentAsQuery(string name, int n) {
      // FilterQuery
      (
        name = "aggregate" and n = 0
        or
        name = "count" and n = 0
        or
        name = "countDocuments" and n = 0
        or
        name = "deleteMany" and n = 0
        or
        name = "deleteOne" and n = 0
        or
        name = "distinct" and n = 1
        or
        name = "find" and n = 0
        or
        name = "findOne" and n = 0
        or
        name = "findOneAndDelete" and n = 0
        or
        name = "findOneAndRemove" and n = 0
        or
        name = "findOneAndReplace" and n = 0
        or
        name = "findOneAndUpdate" and n = 0
        or
        name = "remove" and n = 0
        or
        name = "replaceOne" and n = 0
        or
        name = "update" and n = 0
        or
        name = "updateMany" and n = 0
        or
        name = "updateOne" and n = 0
      )
      or
      // UpdateQuery
      (
        name = "findOneAndUpdate" and n = 1
        or
        name = "update" and n = 1
        or
        name = "updateMany" and n = 1
        or
        name = "updateOne" and n = 1
      )
    }
  }
}

/**
 * Provides classes modeling the Mongoose library.
 */
private module Mongoose {
  /**
   * Gets an import of Mongoose.
   */
  API::Node getAMongooseInstance() { result = API::moduleImport("mongoose") }

  /**
   * Gets a reference to `mongoose.createConnection`.
   */
  API::Node createConnection() { result = getAMongooseInstance().getMember("createConnection") }

  /**
   * A Mongoose function.
   */
  private class MongooseFunction extends API::Node {
    /**
     * Gets the API node for the result from this function (if the function returns a Query).
     */
    abstract API::Node getQueryReturn();

    /**
     * Holds if this function returns a `Query` that evaluates to one or
     * more Documents (`asArray` is false if it evaluates to a single
     * Document).
     */
    abstract predicate returnsDocumentQuery(boolean asArray);

    /**
     * Gets an argument that this function interprets as a query.
     */
    abstract API::Node getQueryArgument();
  }

  /**
   * Provides classes modeling the Mongoose Model class
   */
  module Model {
    private class ModelFunction extends MongooseFunction {
      string methodName;

      ModelFunction() { this = getModelObject().getMember(methodName) }

      override API::Node getQueryReturn() {
        MethodSignatures::returnsQuery(methodName) and result = this.getReturn()
      }

      override predicate returnsDocumentQuery(boolean asArray) {
        MethodSignatures::returnsDocumentQuery(methodName, asArray)
      }

      override API::Node getQueryArgument() {
        exists(int n |
          MethodSignatures::interpretsArgumentAsQuery(methodName, n) and
          result = this.getParameter(n)
        )
      }
    }

    /**
     * A Mongoose collection based on the type `mongoose.Model`.
     */
    private class TypedMongooseModel extends API::EntryPoint {
      TypedMongooseModel() { this = "TypedMongooseModel" }

      override DataFlow::SourceNode getAUse() { result.hasUnderlyingType("mongoose", "Model") }

      override DataFlow::Node getARhs() { none() }
    }

    /**
     * Gets a API node referring to a Mongoose Model object.
     */
    private API::Node getModelObject() {
      result = getAMongooseInstance().getMember("model").getReturn()
      or
      exists(API::Node conn | conn = createConnection().getReturn() |
        result = conn.getMember("model").getReturn() or
        result = conn.getMember("models").getAMember()
      )
      or
      result = any(TypedMongooseModel c).getNode()
    }

    /**
     * Provides signatures for the Model methods.
     */
    module MethodSignatures {
      /**
       * Holds if Model method `name` interprets parameter `n` as a query.
       */
      predicate interpretsArgumentAsQuery(string name, int n) {
        // implement lots of the MongoDB collection interface
        MongoDB::CollectionMethodSignatures::interpretsArgumentAsQuery(name, n)
        or
        name = "findByIdAndUpdate" and n = 1
        or
        name = "where" and n = 0
      }

      /**
       * Holds if Model method `name` returns a Query.
       */
      predicate returnsQuery(string name) {
        name = "$where" or
        name = "count" or
        name = "countDocuments" or
        name = "deleteMany" or
        name = "deleteOne" or
        name = "find" or
        name = "findById" or
        name = "findByIdAndDelete" or
        name = "findByIdAndRemove" or
        name = "findByIdAndUpdate" or
        name = "findOne" or
        name = "findOneAndDelete" or
        name = "findOneAndRemove" or
        name = "findOneAndReplace" or
        name = "findOneAndUpdate" or
        name = "geosearch" or
        name = "replaceOne" or
        name = "update" or
        name = "updateMany" or
        name = "updateOne" or
        name = "where"
      }

      /**
       * Holds if Document method `name` returns a query that results in
       * one or more documents, the documents are wrapped in an array
       * if `asArray` is true.
       */
      predicate returnsDocumentQuery(string name, boolean asArray) {
        asArray = false and name = "findOne"
        or
        asArray = true and name = "find"
      }
    }
  }

  /**
   * Provides classes modeling the Mongoose Query class
   */
  module Query {
    private class QueryFunction extends MongooseFunction {
      string methodName;

      QueryFunction() { this = getAMongooseQuery().getMember(methodName) }

      override API::Node getQueryReturn() {
        MethodSignatures::returnsQuery(methodName) and result = this.getReturn()
      }

      override predicate returnsDocumentQuery(boolean asArray) {
        MethodSignatures::returnsDocumentQuery(methodName, asArray)
      }

      override API::Node getQueryArgument() {
        exists(int n |
          MethodSignatures::interpretsArgumentAsQuery(methodName, n) and
          result = this.getParameter(n)
        )
      }
    }

    private class NewQueryFunction extends MongooseFunction {
      NewQueryFunction() { this = getAMongooseInstance().getMember("Query") }

      override API::Node getQueryReturn() { result = this.getInstance() }

      override predicate returnsDocumentQuery(boolean asArray) { none() }

      override API::Node getQueryArgument() { result = this.getParameter(2) }
    }

    /**
     * A Mongoose query.
     */
    private class TypedMongooseQuery extends API::EntryPoint {
      TypedMongooseQuery() { this = "TypedMongooseQuery" }

      override DataFlow::SourceNode getAUse() { result.hasUnderlyingType("mongoose", "Query") }

      override DataFlow::Node getARhs() { none() }
    }

    /**
     * Gets a data flow node referring to a Mongoose query object.
     */
    API::Node getAMongooseQuery() {
      result = any(MongooseFunction f).getQueryReturn()
      or
      result = any(TypedMongooseQuery c).getNode()
      or
      result =
        getAMongooseQuery()
            .getMember(any(string name | MethodSignatures::returnsQuery(name)))
            .getReturn()
    }

    /**
     * Provides signatures for the Query methods.
     */
    module MethodSignatures {
      /**
       * Holds if Query method `name` interprets parameter `n` as a query.
       */
      predicate interpretsArgumentAsQuery(string name, int n) {
        n = 0 and
        (
          name = "and" or
          name = "count" or
          name = "countDocuments" or
          name = "deleteMany" or
          name = "deleteOne" or
          name = "elemMatch" or
          name = "find" or
          name = "findOne" or
          name = "findOneAndDelete" or
          name = "findOneAndRemove" or
          name = "findOneAndReplace" or
          name = "findOneAndUpdate" or
          name = "merge" or
          name = "nor" or
          name = "or" or
          name = "remove" or
          name = "replaceOne" or
          name = "setQuery" or
          name = "setUpdate" or
          name = "update" or
          name = "updateMany" or
          name = "updateOne" or
          name = "where"
        )
        or
        n = 1 and
        (
          name = "distinct" or
          name = "findOneAndUpdate" or
          name = "update" or
          name = "updateMany" or
          name = "updateOne"
        )
      }

      /**
       * Holds if Query method `name` returns a Query.
       */
      predicate returnsQuery(string name) {
        name = "$where" or
        name = "J" or
        name = "all" or
        name = "and" or
        name = "batchsize" or
        name = "box" or
        name = "center" or
        name = "centerSphere" or
        name = "circle" or
        name = "collation" or
        name = "comment" or
        name = "count" or
        name = "countDocuments" or
        name = "distinct" or
        name = "elemMatch" or
        name = "equals" or
        name = "error" or
        name = "estimatedDocumentCount" or
        name = "exists" or
        name = "explain" or
        name = "find" or
        name = "findById" or
        name = "findOne" or
        name = "findOneAndRemove" or
        name = "findOneAndUpdate" or
        name = "geometry" or
        name = "get" or
        name = "gt" or
        name = "gte" or
        name = "hint" or
        name = "in" or
        name = "intersects" or
        name = "lean" or
        name = "limit" or
        name = "lt" or
        name = "lte" or
        name = "map" or
        name = "map" or
        name = "maxDistance" or
        name = "maxTimeMS" or
        name = "maxscan" or
        name = "mod" or
        name = "ne" or
        name = "near" or
        name = "nearSphere" or
        name = "nin" or
        name = "or" or
        name = "orFail" or
        name = "polygon" or
        name = "populate" or
        name = "read" or
        name = "readConcern" or
        name = "regexp" or
        name = "remove" or
        name = "select" or
        name = "session" or
        name = "set" or
        name = "setOptions" or
        name = "setQuery" or
        name = "setUpdate" or
        name = "size" or
        name = "skip" or
        name = "slaveOk" or
        name = "slice" or
        name = "snapshot" or
        name = "sort" or
        name = "update" or
        name = "w" or
        name = "where" or
        name = "within" or
        name = "wtimeout"
      }

      /**
       * Holds if Query method `name` returns a query that results in
       * one or more documents, the documents are wrapped in an array
       * if `asArray` is true.
       */
      predicate returnsDocumentQuery(string name, boolean asArray) {
        asArray = false and name = "findOne"
        or
        asArray = true and name = "find"
      }
    }
  }

  /**
   * Provides classes modeling the Mongoose Document class
   */
  module Document {
    private class DocumentFunction extends MongooseFunction {
      string methodName;

      DocumentFunction() { this = getAMongooseDocument().getMember(methodName) }

      override API::Node getQueryReturn() {
        MethodSignatures::returnsQuery(methodName) and result = this.getReturn()
      }

      override predicate returnsDocumentQuery(boolean asArray) {
        MethodSignatures::returnsDocumentQuery(methodName, asArray)
      }

      override API::Node getQueryArgument() {
        exists(int n |
          MethodSignatures::interpretsArgumentAsQuery(methodName, n) and
          result = this.getParameter(n)
        )
      }
    }

    /**
     * A Mongoose Document that is retrieved from the backing database.
     */
    class RetrievedDocument extends API::Node {
      RetrievedDocument() {
        exists(boolean asArray, API::Node param |
          exists(MongooseFunction func |
            func.returnsDocumentQuery(asArray) and
            param = func.getLastParameter().getParameter(1)
          )
          or
          exists(API::Node f, string executor, int paramIndex |
            executor = "then" and paramIndex = 0
            or
            executor = "exec" and paramIndex = 1
          |
            f = Query::getAMongooseQuery().getMember(executor) and
            param = f.getParameter(0).getParameter(paramIndex) and
            exists(DataFlow::MethodCallNode pred |
              // limitation: look at the previous method call	
              Query::MethodSignatures::returnsDocumentQuery(pred.getMethodName(), asArray) and
              pred.getAMethodCall() = f.getACall()
            )
          )
        |
          asArray = false and this = param
          or
          asArray = true and
          // limitation: look for direct accesses
          this = param.getUnknownMember()
        )
      }
    }

    /**
     * A Mongoose document.
     */
    private class TypedMongooseDocument extends API::EntryPoint {
      TypedMongooseDocument() { this = "TypedMongooseDocument" }

      override DataFlow::SourceNode getAUse() { result.hasUnderlyingType("mongoose", "Document") }

      override DataFlow::Node getARhs() { none() }
    }

    /**
     * Gets a data flow node referring to a Mongoose Document object.
     */
    private API::Node getAMongooseDocument() {
      result instanceof RetrievedDocument or
      result = any(TypedMongooseDocument c).getNode() or
      result =
        getAMongooseDocument()
            .getMember(any(string name | MethodSignatures::returnsDocument(name)))
            .getReturn()
    }

    private module MethodSignatures {
      /**
       * Holds if Document method `name` returns a Query.
       */
      predicate returnsQuery(string name) {
        // Documents are subtypes of Models
        Model::MethodSignatures::returnsQuery(name) or
        name = "replaceOne" or
        name = "update" or
        name = "updateOne"
      }

      /**
       * Holds if Document method `name` interprets parameter `n` as a query.
       */
      predicate interpretsArgumentAsQuery(string name, int n) {
        // Documents are subtypes of Models
        Model::MethodSignatures::interpretsArgumentAsQuery(name, n)
        or
        n = 0 and
        (
          name = "replaceOne" or
          name = "update" or
          name = "updateOne"
        )
      }

      /**
       * Holds if Document method `name` returns a query that results in
       * one or more documents, the documents are wrapped in an array
       * if `asArray` is true.
       */
      predicate returnsDocumentQuery(string name, boolean asArray) {
        // Documents are subtypes of Models
        Model::MethodSignatures::returnsDocumentQuery(name, asArray)
      }

      /**
       * Holds if Document method `name` returns a Document.
       */
      predicate returnsDocument(string name) {
        name = "depopulate" or
        name = "init" or
        name = "populate" or
        name = "overwrite"
      }
    }
  }

  /**
   * An expression passed to `mongoose.createConnection` to supply credentials.
   */
  class Credentials extends CredentialsExpr {
    string kind;

    Credentials() {
      exists(string prop |
        this = createConnection().getParameter(3).getMember(prop).getARhs().asExpr()
      |
        prop = "user" and kind = "user name"
        or
        prop = "pass" and kind = "password"
      )
    }

    override string getCredentialsKind() { result = kind }
  }

  /**
   * An expression that is interpreted as a (part of a) MongoDB query.
   */
  class MongoDBQueryPart extends NoSQL::Query {
    MongooseFunction f;

    MongoDBQueryPart() { this = f.getQueryArgument().getARhs().asExpr() }

    override DataFlow::Node getACodeOperator() {
      result = getADollarWhereProperty(f.getQueryArgument())
    }
  }

  /**
   * An evaluation of a MongoDB query.
   */
  class ShorthandQueryEvaluation extends DatabaseAccess, DataFlow::InvokeNode {
    MongooseFunction f;

    ShorthandQueryEvaluation() {
      this = f.getACall() and
      // shorthand for execution: provide a callback
      exists(f.getQueryReturn()) and
      exists(this.getCallback(this.getNumArgument() - 1))
    }

    override DataFlow::Node getAQueryArgument() {
      // NB: the complete information is not easily accessible for deeply chained calls
      f.getQueryArgument().getARhs() = result
    }
  }

  class ExplicitQueryEvaluation extends DatabaseAccess {
    ExplicitQueryEvaluation() {
      // explicit execution using a Query method call
      Query::getAMongooseQuery().getMember(["exec", "then", "catch"]).getACall() = this
    }

    override DataFlow::Node getAQueryArgument() {
      // NB: the complete information is not easily accessible for deeply chained calls
      none()
    }
  }
}

/**
 * Provides classes modeling the Minimongo library.
 */
private module Minimongo {
  /**
   * Provides signatures for the Collection methods.
   */
  module CollectionMethodSignatures {
    /**
     * Holds if Collection method `name` interprets parameter `n` as a query.
     */
    predicate interpretsArgumentAsQuery(string m, int queryArgIdx) {
      // implements most of the MongoDB interface
      MongoDB::CollectionMethodSignatures::interpretsArgumentAsQuery(m, queryArgIdx)
    }
  }

  /** A call to a Minimongo query method. */
  private class QueryCall extends DatabaseAccess, DataFlow::MethodCallNode {
    int queryArgIdx;
    API::Node callee;

    QueryCall() {
      exists(string m |
        callee = API::moduleImport("minimongo").getAMember().getReturn().getAMember().getMember(m) and
        this = callee.getACall() and
        CollectionMethodSignatures::interpretsArgumentAsQuery(m, queryArgIdx)
      )
    }

    override DataFlow::Node getAQueryArgument() { result = getArgument(queryArgIdx) }

    DataFlow::Node getACodeOperator() {
      result = getADollarWhereProperty(callee.getParameter(queryArgIdx))
    }
  }

  /**
   * An expression that is interpreted as a Minimongo query.
   */
  class Query extends NoSQL::Query {
    QueryCall qc;

    Query() { this = qc.getAQueryArgument().asExpr() }

    override DataFlow::Node getACodeOperator() { result = qc.getACodeOperator() }
  }
}

/**
 * Provides classes modeling the MarsDB library.
 */
private module MarsDB {
  /** A call to a MarsDB query method. */
  private class QueryCall extends DatabaseAccess, DataFlow::MethodCallNode {
    int queryArgIdx;
    API::Node callee;

    QueryCall() {
      exists(string m |
        callee = API::moduleImport("marsdb").getMember("Collection").getInstance().getMember(m) and
        this = callee.getACall() and
        // implements parts of the Minimongo interface
        Minimongo::CollectionMethodSignatures::interpretsArgumentAsQuery(m, queryArgIdx)
      )
    }

    override DataFlow::Node getAQueryArgument() { result = getArgument(queryArgIdx) }

    DataFlow::Node getACodeOperator() {
      result = getADollarWhereProperty(callee.getParameter(queryArgIdx))
    }
  }

  /**
   * An expression that is interpreted as a MarsDB query.
   */
  class Query extends NoSQL::Query {
    QueryCall qc;

    Query() { this = qc.getAQueryArgument().asExpr() }

    override DataFlow::Node getACodeOperator() { result = qc.getACodeOperator() }
  }
}
