"use strict";

/** The columns a table has in this game's database, which differ from game to game. */
function readTableColumnNames(database, table) {
  return database.prepare("SELECT name FROM pragma_table_info(?)").all(table).map((column) => column.name);
}

module.exports = { readTableColumnNames };
