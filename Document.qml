import QtQuick 2.0
import "../qml-extras"

Object {
    id: doc

    property string _id: ""
    property string _type: "Document"
    property var _properties: []
    property bool _delayLoad: false

    property var _db
    property bool isLoaded

    signal created
    signal loaded
    signal removed

    property var _metadata

    Connections {
        target: _db
        onLoaded: {
            print('Database loaded, triggering doc load: ', _id)
            init()
        }
    }

    Component.onCompleted: init()

    function init() {
        print('Loading document')
        initMetadata()

        if (!_db.dbOpen || isLoaded) {
            return
        }

        _db.registerType(doc)

        print('DB Open, loading')

        if (!_id) {
            print('No ID, creating one')
            _id = generateID()
            created()

            if (!_delayLoad) {
                register()
            }

            _db.saveObject(doc)
        } else {
            if (!_delayLoad) {
                print('Loading...')
                var info = _db.getById(doc._type, doc._id)

                load(info)
            }
        }
    }

    function initMetadata() {
        var type = {
            'type': doc._type
        }

        var propertyInfo = {}
        _properties.forEach(function(prop) {
            var jsType = doc[prop] == undefined ? 'object' : typeof(doc[prop])

            if (doc[prop] instanceof Array)
                jsType = 'array'
            if (doc[prop] instanceof Date)
                jsType = 'date'

            propertyInfo[prop] = jsType
        })

        type['properties'] = propertyInfo

        _metadata = type
    }

    function load(data) {
        print('Loading data:', JSON.stringify(data))
        if (data === undefined) {
            _db.saveObject(doc)
        } else {
            print(JSON.stringify(data))
            for (var prop in data) {
                if (prop === 'id' || prop.indexOf('_') === 0)
                    continue

                _db.debug(prop, "=", data[prop])
                if (JSON.stringify(doc[prop]) !== JSON.stringify(data[prop])) {
                    _db.debug("  --> Loaded", doc[prop])

                    if (doc._metadata.properties[prop] == 'date') {
                        var value = new Date(data[prop])
                        print("Value: ", data[prop], value)
                        doc[prop] = value == null ? new Date("") : value
                    } else if (doc._metadata.properties[prop] == 'object') {
                        print("Property", prop, data[prop], typeof(doc[prop]))
                        doc[prop] = data[prop] == "undefined" ? undefined : JSON.parse(data[prop])
                    } else if (doc._metadata.properties[prop] == 'string')
                        doc[prop] = data[prop] == null ? "" : data[prop]
                    else
                        doc[prop] = data[prop]
                }
            }
        }

        register()

        loaded()

        isLoaded = true
    }

    property bool _disabled

    function register() {
        _properties.forEach(function(prop) {
            _db.debug('Connecting to', prop)
            doc[prop + 'Changed'].connect(function() {
                if (!_disabled) {
                    _db.debug(prop + " changed to " + doc[prop])

                    _db.set(doc, prop, doc[prop])
                }
            })
        })
    }

    function remove() {
        removed()
        _db.removeById(_type, _id)
    }

    function generateID() {
        var guid = (function() {
          function s4() {
            return Math.floor((1 + Math.random()) * 0x10000)
                       .toString(16)
                       .substring(1);
          }
          return function() {
            return s4() + s4() + '-' + s4() + '-' + s4() + '-' +
                   s4() + '-' + s4() + s4() + s4();
          };
        })()();
        _db.debug(guid)
        return guid
    }

    function toJSON() {
        var json = {}

        _properties.forEach(function(prop) {
            json[prop] = doc[prop]
        })

        return JSON.parse(JSON.stringify(json))
    }
}
