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

    Component.onCompleted: {
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
                    _disabled = true
                    _db.set(doc, prop, doc[prop])
                    _disabled = false
                }
            })
        })

        _db.objectChanged.connect(function(type, docId, key, value) {
            if (type === doc._type && docId === doc._id && key !== 'new' && !_disabled) {
                _disabled = true

                print('NOTIFY --> ' + key + " changed to " + value)

                doc[key] = value

                _disabled = false
            }
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
