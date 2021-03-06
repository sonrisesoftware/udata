import QtQuick 2.0
import QtQuick.LocalStorage 2.0
import "../qml-extras/dateutils.js" as DateUtils

Item {
    id: database

    property var db
    property string name
    property string description
    property int version: 1

    property var cache
    property bool dbOpen

    signal loaded()
    signal upgrade(var tx, var version)

    signal objectChanged(var type, var docId, var key, var value)
    signal objectRemoved(var type, var docId)

    property var registeredTypes: []

    property url modelPath

    onLoaded: {
        registeredTypes = _get('registeredTypes', [])
        print("loaded registered types", registeredTypes)
    }

    function _set(name, value) {
        cache[name] = value
        db.transaction( function(tx){
            print(name, '=', value)
            print(JSON.stringify(value))
            tx.executeSql('INSERT OR REPLACE INTO metadata VALUES(?, ?)', [name, JSON.stringify(value)]);
        });
    }

    function _get(name, def) {
        return cache.hasOwnProperty(name) ? cache[name] : def
    }

    function _has(name) {
        return cache.hasOwnProperty(name)
    }

    function execSQL(sql, args) {
        if (!args)
            args = []
        db.transaction( function(tx){
            tx.executeSql(sql, args);
        });
    }

    function registerType(type) {
        if (registeredTypes.indexOf(type._type) != -1)
            return

        print('Registering', type)

        registeredTypes.push(type._type)
        _set('registeredTypes', registeredTypes)

        var name = type._type
        var sql = 'CREATE TABLE IF NOT EXISTS %1(id TEXT UNIQUE%2)'
        var args = ''
        for (var prop in type._metadata.properties) {
            var sqlType = 'TEXT'
            var jsType = type._metadata.properties[prop]
            print(prop, jsType)

            if (jsType == 'number' ||
                    jsType == 'boolean')
                sqlType = 'FLOAT'
            if (jsType == 'date')
                sqlType = 'DATE'

            args += ', ' + prop + ' ' + sqlType
        }

        db.transaction(function(tx){
            tx.executeSql(sql.arg(name).arg(args));
        });
    }

    function clear() {
        registeredTypes.forEach(function(type) {
            execSQL("DROP TABLE " + type)
        })

        registeredTypes = []
        _set("registeredType", registeredTypes)
    }

    function open() {
        if (db !== undefined) return

        print('Opening database...')

        db = LocalStorage.openDatabaseSync(name, "", description, 100000);

        if (String(db.version) !== String(version)) {
            db.changeVersion(String(db.version), String(version), function (tx) {
                if (db.version === "") {
                    var sql = 'CREATE TABLE IF NOT EXISTS metadata(name TEXT UNIQUE, value TEXT)'
                    print("Creating db...")
                    tx.executeSql(sql);
                }

                upgrade(tx, Number(db.version))
            })
            db = LocalStorage.openDatabaseSync(name, "", description, 100000);
        }

        cache = {}
        db.readTransaction(
            function(tx){
                var rs = tx.executeSql('SELECT name, value FROM metadata');
                for(var i = 0; i < rs.rows.length; i++) {
                    var row = rs.rows.item(i);
                    print(JSON.stringify(row))
                    cache[row.name] = JSON.parse(row.value);
                }
            }
        );

        print(JSON.stringify(cache))

        dbOpen = true

        loaded()

        print('Database open.')
    }

    function countWithPredicate(type, predicate) {
        var result = 0

        if (registeredTypes.indexOf(type) == -1)
            return result

        db.readTransaction(function(tx) {
            var sql = 'SELECT COUNT(*) AS count FROM ' + type
            if (predicate != "" && predicate != undefined)
                sql += ' WHERE ' + predicate
            print(sql)

            var rows = tx.executeSql(sql).rows

            result = rows.item(0).count
        })

        return result
    }

    function queryWithPredicate(type, query, args) {
        print("Querying", query)
        var result = []

        if (!args) args = []

        if (registeredTypes.indexOf(type) == -1)
            return result

        db.readTransaction(function(tx) {
            var sql = 'SELECT * FROM ' + type
            if (query != "" && query != undefined)
                sql += ' WHERE ' + query
            print(sql)

            var rows = tx.executeSql(sql, args).rows
            for(var i = 0; i < rows.length; i++) {
                result.push(rows.item(i))
            }
        })

        return result
    }

    function getByPredicate(type, query, args) {
        var result

        if (registeredTypes.indexOf(type) == -1)
            return undefined

        db.readTransaction(function(tx) {
            var sql = 'SELECT * FROM ' + type
            if (query != "" && query != undefined)
                sql += ' WHERE ' + query
            print(sql)

            var rows = tx.executeSql(sql, args).rows

            result = rows.length === 1 ? rows[0] : undefined
        })

        return result
    }

    function getById(type, id) {
        var result
        db.readTransaction(function(tx) {
            var sql = 'SELECT * FROM %1 WHERE id==\'%2\''.arg(type).arg(id)
            print(sql)

            var rows = tx.executeSql(sql).rows

            result = rows.length > 0 ? rows[0] : undefined
        })

        return result
    }

    function removeById(type, id) {
        removeWithPredicate(type, "id == '%1'".arg(id))
    }

    function removeWithPredicate(type, predicate) {
        var list = queryWithPredicate(type, predicate)

        db.transaction( function(tx) {
            var sql = 'DELETE FROM %1'.arg(type)
            if (predicate != "" && predicate != undefined)
                sql += ' WHERE ' + predicate
            print(sql)

            tx.executeSql(sql);
        });

        list.forEach(function (obj) {
            objectRemoved(type, obj.id)
        })
    }

    function set(type, field, value) {
        var original = value

        db.transaction( function(tx){
            if (type._metadata.properties[field] == 'date')
                value = DateUtils.isValid(value) ? value.toISOString() : ""
            else if (typeof(value) == 'object')
                value = JSON.stringify(value)

            var sql = 'UPDATE %1 SET %2 = ? WHERE id==?'.arg(type._type).arg(field)
            print(sql)
            tx.executeSql(sql, [value, type._id]);

            objectChanged(type._type, type._id, field, original)
        });
    }

    function saveObject(type) {
        db.transaction( function(tx) {
            var args = "'%1'".arg(type._id)
            type._properties.forEach(function(prop) {
                var value = type[prop]
                if (type._metadata.properties[prop] == 'date')
                    value = DateUtils.isValid(value) ? value.toISOString() : ""
                else if (typeof(value) == 'object')
                    value = JSON.stringify(value)

                args += ", '%1'".arg(value)
            })
            print(args)

            tx.executeSql('INSERT OR REPLACE INTO %1 VALUES (%2)'.arg(type._type).arg(args));

            objectChanged(type._type, type._id, 'new', '')
        });
    }

    function contains(type) {
        return type._id !== "" && get(type) !== undefined
    }

    Component.onCompleted: if (db == undefined) open()

    /*
     * Call this to create a new model object
     *
     * @param type The type of your model object, without the path and without '.qml' at the end.
     * @param args The initial values for properties in the object
     * @param parent the parent object to assign this object to (used by Qt, and not stored used by uData at all)
     */
    function create(type, args, parent) {
        if (!args)
            args = {}

        var obj = newObject(type, args, parent)

        return obj
    }

    /*
     * Used internally to load objects based on their IDs
     */
    function loadById(type, id, parent) {
        return newObject(type, {_id: id, _type: type}, parent)
    }

    function loadFromData(type, data, parent) {
        var obj = newObject(type, {_id: data['id'], _type: type, _delayLoad: true}, parent)
        obj.load(data)

        return obj
    }

    /*
     * Used internally to load objects based on their IDs
     */
    function loadWithData(type, id, data, parent) {
        var obj = newObject(type, {_id: id, _type: type, _delayLoad: true}, parent)

        if (data == undefined)
            data = get(type, id)

        obj.load(data)

        return obj
    }

    /*
     * Used internally to load an object from a file
     */
    function newObject(type, args, parent) {
        if (!args)
            args = {}
        if (!parent)
            parent = database

        args._db = database
        args.parent = parent

        var path = type == 'Document' ? Qt.resolvedUrl(type + '.qml') : modelPath + '/' + type + '.qml'

        var component = Qt.createComponent(path);
        if (component.status == Component.Error) {
            // Error Handling
            console.log("Error loading component:", component.errorString());
        }

        return component.createObject(parent, args);
    }

    property bool debugMode

    function debug(msg) {
        if (debugMode)
            print(msg)
    }
}
