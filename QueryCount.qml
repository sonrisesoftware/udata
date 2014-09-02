import QtQuick 2.0
import "../qml-extras"

Object {
    id: query

    property var _db

    property int count
    property string type
    property string predicate

    onPredicateChanged: timer.start()
    onTypeChanged: timer.start()

    Component.onCompleted: {
        _db.objectChanged.connect(function (type, docId) {
            if (query && type == query.type)

                timer.start()
        })
        _db.objectRemoved.connect(function (type, docId) {
            if (query && type == query.type)
                timer.start()
        })

        timer.start()
    }

    Timer {
        id: timer
        interval: 10
        onTriggered: reload()
    }

    function reload() {
        if (_db == undefined)
            return

        count = _db.countWithPredicate(type, predicate)
    }
}
