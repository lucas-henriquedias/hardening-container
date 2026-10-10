const http = require('http');
const PORT = process.env.PORT || 3000;

http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Olá mundo!\n');
}).listen(PORT, '0.0.0.0', () => console.log('Olá mundo! Porta ' + PORT));

