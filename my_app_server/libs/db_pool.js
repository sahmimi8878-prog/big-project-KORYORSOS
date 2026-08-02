const mariadb = require('mariadb');

const pool = mariadb.createPool({
  host: 'localhost',
  user: 'root',
  password: '150147',
  database: 'Koryorsos',
  port: 3306,
  connectionLimit: 5
});

module.exports = pool;