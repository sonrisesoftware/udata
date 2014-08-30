import QtQuick 2.0


Rectangle {
    width: 360
    height: 360
    ListView {
        anchors.fill: parent
        model: list
        spacing: 10
        delegate: Text {
            text: modelData.random + " (" + modelData._id + ")"
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            var object = db.create('SampleObject', {'random': i++})
            print('Setting special')
            if (object.random === 4)
                object.special = 'YES'
            else
                object.special = 'NO'
        }
    }

    property int i: 0

    Query {
        id: list
        type: "SampleObject"
        sortBy: 'random'

        predicate: "random >= 3 AND special == 'YES'"

        _db: db
    }

    Database {
        id: db

        name: "storage_demo"
        modelPath: Qt.resolvedUrl(".")
    }
}

