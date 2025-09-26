const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Aurora API Gateway is running!');
});

app.listen(port, () => {
  console.log(`API Gateway listening on port ${port}`);
});
