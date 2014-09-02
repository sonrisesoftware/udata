import QtQuick 2.0
import "../qml-extras"

Object {
    id: query

    property var _db

    property int count
    property string type
    property string predicate

    property bool enabled: true
    property bool updateNeeded: true

    onEnabledChanged: {
        if (enabled && updateNeeded)
            timer.start()
    }

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
        onTriggered: {
            if (enabled)
                reload()
            else
                updateNeeded = true
        }
    }

    function reload() {
        if (_db == undefined)
            return

        updateNeeded = false

        count = _db.countWithPredicate(type, predicate)
    }
}
