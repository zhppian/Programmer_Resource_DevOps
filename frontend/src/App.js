import React, { useEffect, useState } from "react";

function App() {
  const [message, setMessage] = useState("");

  useEffect(() => {
    const backendUrl = process.env.REACT_APP_BACKEND_URL || ""; // Use environment variable
    fetch(`${backendUrl}/api/hello`)
      .then((response) => response.json())
      .then((data) => setMessage(data.message))
      .catch((error) => console.error("Error fetching the API:", error));
  }, []);

  return (
    <div>
      <h1>React + Flask in One Docker!</h1>
      <p>{message}</p>
    </div>
  );
}

export default App;
