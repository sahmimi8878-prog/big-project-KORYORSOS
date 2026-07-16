const mariadb = require('mariadb');

const pool = mariadb.createPool({
  host: 'localhost',
  user: 'root',
  password: '12345',
  database: 'Koryorsos',
  port: 3306,
  connectionLimit: 5
});

module.exports = pool;