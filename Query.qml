import QtQuick 2.0

ListModel {
    id: model

    property string predicate: ""
    property string sortBy: "id"

    /*!
      This is necessary so that the ListView sections correctly update.

      Set this property to the name of a property in your model object (it can
      include subproperties, seperated by `.`), and then in your ListView, set
      section.property to "section".
     */
    property string groupBy: ""
    property bool sortAscending: true

    property string type: "Document"

    property var _db

    property var docIDs: []
    property var data: {}

    property bool finishedLoading

    onPredicateChanged: {
        if (_db === undefined || !finishedLoading)
            return

        var list = _db.queryWithPredicate(type, predicate)
        var newDocIDs = []

        list.forEach(function (data) {
            var docId = data.id

            newDocIDs.push(docId)
            var obj = _db.loadWithData(type, docId, data, model)

            if (docIDs.indexOf(docId) == -1) {
                print("Section[%1]".arg(groupBy), _get(obj, groupBy))

                model.data[docId] = data

                docIDs.push(docId)

                // Add it at the right location
                if (sortBy == "") {
                    model.append({'modelData': obj, "section": _get(obj, groupBy)})
                } else {
                    sort()

                    var index = docIDs.indexOf(docId)
                    model.insert(index, {'modelData': obj, "section": _get(obj, groupBy)})
                }
            } else {
                var currentIndex = docIDs.indexOf(docId)

                model.data[docId] = data
                sort()

                var newIndex = docIDs.indexOf(docId)

                model.move(currentIndex, newIndex, 1)
                print("Replacing object at index", newIndex)
                model.set(newIndex, {'modelData': obj, "section": _get(obj, groupBy)})
//                model.setProperty(newIndex, "section", _get(model.at(newIndex), groupBy))
            }
        })


        // Remove any documents that are currently in the model but not in the query
        var i = 0;
        while (i < docIDs.length) {
            var docId = docIDs[i]

            if (newDocIDs.indexOf(docId) == -1) {
                _removeDoc(docId)
            } else {
                i++
            }
        }
    }

    Component.onCompleted: init()

    function init () {
        if (finishedLoading)
            return

        print("Loading query...")
        _db.objectChanged.connect(model.update)
        _db.objectRemoved.connect(model.onRemove)
        print(type)
        reload()
    }

    function at(index) {
        return get(index).modelData
    }

    function onRemove(type, docId) {
        print('Removing', docId, 'of type', type)
        if (model && finishedLoading && type == model.type) {
            if (docIDs.indexOf(docId) !== -1)
                _removeDoc(docId)
        }
    }

    function update(type, docId) {
        print('Updating', docId, 'of type', type)
        if (model && finishedLoading && type == model.type) {
            var data

            var add = true

            if (predicate != "") {
                var list = _db.queryWithPredicate(type, "id == '%1' AND %2".arg(docId).arg(predicate))
                add = list.length > 0

                if (add)
                    data = list[0]
            } else {
                data = _db.queryWithPredicate(type, "id == '%1'".arg(docId))[0]
            }

            if (add) {
                var obj = _db.loadWithData(type, docId, data, model)
                if (docIDs.indexOf(docId) == -1) {

                    model.data[docId] = data

                    docIDs.push(docId)

                    // Add it at the right location
                    if (sortBy == "") {
                        model.append({'modelData': obj, "section": _get(obj, groupBy)})
                    } else {
                        sort()

                        var index = docIDs.indexOf(docId)
                        model.insert(index, {'modelData': obj, "section": _get(obj, groupBy)})
                    }
                } else {
                    var currentIndex = docIDs.indexOf(docId)

                    model.data[docId] = data
                    sort()

                    var newIndex = docIDs.indexOf(docId)

                    model.move(currentIndex, newIndex, 1)

                    print("Replacing object at index", newIndex)
                    model.set(newIndex, {'modelData': obj, "section": _get(obj, groupBy)})
                }
            } else {
                print("Removing", docIDs.indexOf(docId))
                if (docIDs.indexOf(docId) !== -1)
                    _removeDoc(docId)
            }
        }
    }

    function _removeDoc(docId) {
        print("Removing item from model...")
        model.remove(docIDs.indexOf(docId))
        docIDs.splice(docIDs.indexOf(docId), 1)
        delete data[docId]
    }

    function reload() {
        model.clear()

        docIDs = []
        data = {}


        print("Empty db")
        if (_db == undefined)
            return

        var matchingData = _db.queryWithPredicate(type, predicate)

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
            model.append({'modelData': obj, "section": _get(obj, groupBy)})
        }

        finishedLoading = true
    }

    function sort() {
        var list = sortBy.split(",")

        docIDs = docIDs.sort(function (b, a) {
            for (var i = 0; i < list.length; i++) {
                var prop = list[i]

                var value1 = data[a][prop]
                var value2 = data[b][prop]
                var type = typeof(value1)

                if (!isNaN(value1) && !isNaN(value2))
                    type = 'number'
                if (value1 instanceof Date)
                    type = 'date'

                var sort = 0

                if (type == 'boolean') {
                    sort = Number(value2) - Number(value1)
                } else if (type == 'string') {
                    sort = value2.localeCompare(value1)
                } else if (type == 'date') {
                    sort = value2 - value1
                } else {
                    sort = Number(value2) - Number(value1)
                }

                sort = sort * (sortAscending ? 1 : -1)

                if (sort != 0)
                    return sort
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
