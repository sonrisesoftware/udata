import QtQuick 2.0

QtObject {
    id: model

    property string predicate: ""

    property string type: "Document"

    property Database _db

    property bool finishedLoading

    property Document object
    property Item parent

    onPredicateChanged: {
        reload()
    }

    Component.onCompleted: init()

    function init () {
        if (finishedLoading)
            return

        print("Loading query...")
        _db.objectChanged.connect(model.reload)
        _db.objectRemoved.connect(model.reload)
        _db.loaded.connect(model.reload)
        print(type)
        reload()
    }

    function at(index) {
        return get(index).modelData
    }

    function reload() {
        if (_db == undefined || !_db.dbOpen)
            return

        var data = _db.getByPredicate(type, predicate)

        if (data) {
            object = _db.loadFromData(type, data, parent)
        } else {
            object = null
        }

        finishedLoading = true
    }
}
