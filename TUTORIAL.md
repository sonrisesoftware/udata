uData
=====

###Model Objects###

The core part of uData is the model object. It's full QML object, so you get strongly typed properties, property change signals, bindings, and functions.

To defined a model object, create a new type and name the name of your model object. For example, let's create a todo list app. We'll create a new QML class and name it `Task.qml`:

    Document {
        _type: "Task"
        _properties: ["title", "completed"]
        
        property string title
        property bool completed: false
    }
    
So, the first thing you'll notice is that model objects must inherit `Document`. This gives it some basic functionallity.

To define a model object, you need to set two properties: `_type`, and `_properties`. `_type` Tells the storage system what type that object is, since QML doesn't let us query the object type. `_properties` tells the storage system which properties to save to the database.

###Creating an Object###

So, we've created a beautiful UI that lets us add tasks. But how do we actually save them to the storage model? Simple:

var task = database.create("Task", {
        title: "A sample task",
    })
    
This creates a `Task` object and saves it to the storage model. Note something: We only passed in `title`. `completed` is not set, but just uses the default value we defined earlier, `false`.

###Queries###

A query is basically a list model that contains a set of objects matching a given predicate.

For example, if we want to display all our tasks that haven't been completed yet, we could do something like this:

    Query {
        id: tasksModel
        
        type: "Task"
        predicate: "completed==0"
    }
    
Or we could not set a predicate, and display all tasks:

    Query {
        id: tasksModel
        
        type: "Task"
    }
    
Now we can display that query just like a `ListModel`:

    ListView {
        model: tasksModel
        delegate: ListItem.Standard {
            text: modelData.title
        }
    }
    
**Sorting Queries**

Right now, our tasks list is sorted randomly. But it doesn't have to be. We can sort alphabetically by title:

    Query {
        id: tasksModel
        
        type: "Task"
        sortBy: "title"
    }
    
Or by completion status:


    Query {
        id: tasksModel
        
        type: "Task"
        sortBy: "completed"
    }
    
Or sort by completion status then by title:
    
    Query {
        id: tasksModel
        
        type: "Task"
        sortBy: "completed,title"
    }
    
**Grouping Query Results**

ListViev gives us the set of section properties, which let us group list items under different section headers. However, it has trouble when the model objects are QtObjects, and not JSON. So, uData provides a handy wrapper around that.

Let's say we want to group our tasks into two categories: "Upcoming", and "Completed". Back in our `Task.qml` file, lets add a property for that:

    Document {
        _type: "Task"
        _properties: ["title", "completed"]
        
        property string title
        property bool completed: false
        
        property string sectionTitle: completed ? "Completed" : "Upcoming"
    }
    
Note that this property is a binding, and is not persisted to the storage database.

Now, in our Query, add the `groupBy` property:

    Query {
        id: tasksModel
        
        type: "Task"
        sortBy: "completed,title"
        groupBy: "sectionTitle"
    }
    
And now we can use a special property that Query created called `section`:

    ListView {
        model: tasksModel
        delegate: ListItem.Standard {
            text: modelData.title
        }
        
        section.property: "section"
        section.delegate: ListItem.Header {
            text: section
        }
    }
    
Now your tasks will be grouped into "Upcoming" and "Completed" sections!

**Animations**

The `Query` object is quite smart when you change the predicate or add/remove/update a model object. Instead of just reloading the entire list of matching objects, it adds, removes, or moves only the objects that need to be changed. This means you can use some fancy animations, like this:

    ListView {
        model: tasksModel
        delegate: ListItem.Standard {
            id: listItem
            text: modelData.title
            
            ListView.onAdd: SequentialAnimation {
                UbuntuNumberAnimation { target: listItem; property: "opacity"; from: 0; to: 1; duration: 400 }
            }
        
            ListView.onRemove: SequentialAnimation {
                PropertyAction { target: listItem; property: "ListView.delayRemove"; value: true }
                UbuntuNumberAnimation { target: listItem; property: "opacity"; to: 0; duration: 400 }
                UbuntuNumberAnimation { target: listItem; property: "height"; to: 0; duration: 200 }
                PropertyAction { target: listItem; property: "ListView.delayRemove"; value: false }
            }
            
        }

        move: Transition {
            UbuntuNumberAnimation { properties: "x,y"; duration: UbuntuAnimation.SlowDuration }
        }
    
        moveDisplaced: Transition {
            UbuntuNumberAnimation { properties: "x,y"; duration: UbuntuAnimation.SlowDuration }
        }
    }
    
Now you get fancy animations when the query updates!

**Passing Model Objects into other Views**

If you want to pass a model object around, say to a details page, just assign it to a variable of the model object's type, for example, `Task`:

    ListView {
        model: tasksModel
        delegate: ListItem.Standard {
            id: listItem
            text: modelData.title
            onClicked: pageStack.push(Qt.resolvedUrl("DetailsPage.qml"), {task: modelData})
        }
    }

    // DetailsPage.qml
    Page {
        property Task task
    }

###Editing and Deleting Objects###

Ok, so now you have a nice list of tasks. But how to we change a task object to mark it as completed? Easy:

    delegate: ListItem.Standard {
        text: modelData.title

        onClicked: modelData.completed = !modelData.completed
    }
    
That's it! Just change a property value and it is automatically saved to the database and updated across any other Queries that you might be using.

To delete an object, just call the `remove()` method:

    var task = ...
    task.remove()
  
###Other features###

There's many more features to uData, like QueryCount, which lets you count the number of objects matching a predicate. More tutorials to come!