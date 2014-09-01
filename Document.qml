import QtQuick 2.0

QtObject {
    id: doc

    property string _id: ""
    property string _type: "Document"
    property var _properties: []
    property bool _delayLoad: false

    property var _db

    signal created
    signal loaded

    property var _metadata

    Component.onCompleted: {
        initMetadata()

        _db.registerType(doc)

        if (!_id) {
            _id = generateID()
            created()

            if (!_delayLoad) {
                register()
            }

            _db.save(doc)
        } else {
            if (!_delayLoad) {
                var info = _db.get(doc._type, doc._id)

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

            propertyInfo[prop] = jsType
        })

        type['properties'] = propertyInfo

        _metadata = type
    }

    function load(data) {
        if (data === undefined) {
            _db.save(doc)
        } else {
            for (var prop in data) {
                if (prop === 'id' || prop.indexOf('_') === 0)
                    continue

                print(prop, "=", data[prop])
                if (JSON.stringify(doc[prop]) !== JSON.stringify(data[prop])) {
                    print("  --> Loaded")

                    if (doc[prop] == undefined || typeof(doc[prop]) == 'object')
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
