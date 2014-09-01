import QtQuick 2.0

QtObject {
    id: query

    property var _db

    property int count
    property string type
    property string predicate

    onPredicateChanged: reload()
    onTypeChanged: reload()

    Component.onCompleted: {
        _db.objectChanged.connect(function (type, docId) {
            if (type == query.type)
                reload()
        })
        _db.objectRemoved.connect(function (type, docId) {
            if (type == query.type)
                reload()
        })

        reload()
    }

    function reload() {
        if (_db == undefined)
            return

        count = _db.query(type, predicate).length
    }
}
