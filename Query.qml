import QtQuick 2.0

ListModel {
    id: model

    property string predicate: ""
    property string sortBy: "id"

    property string type: "Document"

    property var _db

    property var docIDs: []
    property var data: {}

    Component.onCompleted: {
        _db.objectChanged.connect(model.update)
        _db.objectRemoved.connect(model.remove)
        reload()
    }

    function remove(type, docId) {
        if (type == model.type && docIDs.indexOf(docId) !== -1)
            removeDoc(docId)
    }

    function update(type, docId) {
        print('Updating', docId, 'of type', type)
        if (type == model.type) {
            var data

            var add = true

            if (predicate != "") {
                var list = _db.query(type, "id == '%1' AND %2".arg(docId).arg(predicate))
                add = list.length > 0

                if (add)
                    data = list[0]
            } else {
                data = _db.query(type, "id == '%1'".arg(docId))[0]
            }

            if (add) {
                if (docIDs.indexOf(docId) == -1) {
                    var obj = _db.loadWithData(type, docId, data, model)

                    model.data[docId] = data

                    docIDs.push(docId)

                    // Add it at the right location
                    if (sortBy == "") {
                        model.append({'modelData': obj})
                    } else {
                        sort()

                        var index = docIDs.indexOf(docId)
                        model.insert(index, {'modelData': obj})
                    }
                } else {
                    var currentIndex = docIDs.indexOf(docId)

                    model.data[docId] = data
                    sort()

                    var newIndex = docIDs.indexOf(docId)

                    model.move(currentIndex, newIndex, 1)
                }
            } else {
                if (docIDs.indexOf(docId) !== -1)
                    removeDoc(docId)
            }
        }
    }

    function removeDoc(docId) {
        model.remove(docIDs.indexOf(docId))
        docIDs = docIDs.splice(docId, 1)
        delete data[docId]
    }

    function reload() {
        model.clear()

        docIDs = []
        data = {}

        var matchingData = _db.query(type, predicate)

        matchingData.forEach(function (obj) {
            docIDs.push(obj.id)
            data[obj.id] = obj
        })

        if (sortBy != "") {
            sort()
        }

        for (var i = 0; i < docIDs.length; i++) {
            var docId = docIDs[i]
            var obj = _db.loadWithData(type, docId, data[docId], model)
            model.append({'modelData': obj})
        }
    }

    function sort() {

        docIDs = docIDs.sort(function (b, a) {
            print(a, b)
            print(Object.keys(data))
            var value1 = data[a][sortBy]
            var value2 = data[b][sortBy]
            if (typeof(value1) == 'boolean') {
                print(sortBy, value1, value2, Number(value2) - Number(value1))
                return Number(value2) - Number(value1)
            } else if (typeof(value1) == 'string') {
                print(sortBy, value1, value2, value2.localeCompare(value1))

                return value2.localeCompare(value1)
            } else {
                print(sortBy, value1, value2, Number(value2) - Number(value1))
                return Number(value2) - Number(value1)
            }
        })
    }

    function _get(obj, prop) {
        if (prop.indexOf('.') === -1) {
            return obj[prop]
        } else {
            var items = prop.split('.')

            for (var i = 0; i < items.length; i++) {
                obj = obj[items[i]]
                if (obj === undefined)
                    return obj
            }

            return obj
        }
    }
}
