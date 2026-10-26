import { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";

function App() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const onMessage = (event) => {
      if (event.data.action === "setVisible") setVisible(event.data.visible);
    };
    const onKey = (event) => {
      if (event.key !== "Escape") return;
      setVisible(false);
      fetch(`https://${GetParentResourceName()}/close`, { method: "POST", body: "{}" });
    };
    window.addEventListener("message", onMessage);
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("message", onMessage);
      window.removeEventListener("keydown", onKey);
    };
  }, []);

  if (!visible) return null;
  return (
    <div style={{ position: "fixed", right: 24, bottom: 24, padding: "16px 20px", borderRadius: 10,
                  background: "#0d1117", color: "#e6edf3", font: "14px system-ui" }}>
      Hello from example_ui. Press ESC to close.
    </div>
  );
}

createRoot(document.getElementById("root")).render(<App />);
