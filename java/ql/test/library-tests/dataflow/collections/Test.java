import java.util.*;

public class Test {
  static String tainted;

  void sink(Object o) { }

  public void run() {
    HashMap<String, String> m = new HashMap<>();
    String x1 = m.get("key");
    sink(x1); // No flow

    m.put("key", tainted);
    String x2 = m.get("key");
    sink(x2); // Flow

    String x3 = m.values().toArray(new String[1])[0];
    sink(x3); // Flow

    for(Map.Entry<String, String> e : m.entrySet()) {
      String x4 = e.getValue();
      sink(x4); // Flow
    }

    Iterator<String> it = m.values().iterator();
    String x5 = it.next();
    sink(x5); // Flow

    it.forEachRemaining(x6 -> {
      sink(x6); // Flow
    });

    m.forEach((key, value) -> {
      sink(key); // Flow
      sink(value); // Flow
    });

    m.entrySet().forEach(entry -> {
      String x7 = entry.getKey();
      sink(x7); // No flow
      String x8 = entry.getValue();
      sink(x8); // Flow
    });
  }
}
