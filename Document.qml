import QtQuick 2.0
import "../qml-extras"

Object {
    id: doc

    property string _id: ""
    property string _type: "Document"
    property var _properties: []
    property bool _delayLoad: false

    property var _db

    signal created
    signal loaded
    signal removed

    property var _metadata

    Connections {
        target: _db
        onLoaded: init()
    }

    Component.onCompleted: init()

    function init() {
        initMetadata()

        if (!_db.dbOpen) {
            return
        }

        _db.registerType(doc)

        if (!_id) {
            _id = generateID()
            created()

            if (!_delayLoad) {
                register()
            }

            _db.saveObject(doc)
        } else {
            if (!_delayLoad) {
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
        if (data === undefined) {
            _db.saveObject(doc)
        } else {
            for (var prop in data) {
                if (prop === 'id' || prop.indexOf('_') === 0)
                    continue

                print(prop, "=", data[prop])
                if (JSON.stringify(doc[prop]) !== JSON.stringify(data[prop])) {
                    print("  --> Loaded", doc[prop])

                    if (doc._metadata.properties[prop] == 'date') {
                        var value = JSON.parse(data[prop])
                        doc[prop] = value == null ? new Date("") : value
                    } else if (doc[prop] == undefined || typeof(doc[prop]) == 'object')
                        doc[prop] = JSON.parse(data[prop])
                    else
                        doc[prop] = data[prop]
                }
            }
        }

        loaded()

        register()
    }

    property bool _disabled

    function register() {
        _properties.forEach(function(prop) {
            print('Connecting to', prop)
            doc[prop + 'Changed'].connect(function() {
                if (!_disabled) {
                    print(prop + " changed to " + doc[prop])

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
        print(guid)
        return guid
    }
}
