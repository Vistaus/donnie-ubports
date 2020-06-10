/**
 * Donnie. Copyright (C) 2020 Willem-Jan de Hoog
 *
 * License: MIT
 */

import Ergo 0.0

import QtQuick 2.7
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtMultimedia 5.6
import QtGraphicalEffects 1.0

import "../components"

import "../UPnP.js" as UPnP

Page {
    id: browsePage

    property bool showBusy: false
    property string cid : "" // current id
    property int cScrollIndex: -1 // index to scroll to when going 'back'
    property var contents

    property int startIndex: 0
    property int maxCount: app.settings.max_number_of_results
    property int totalCount

    //property string pathTreeText : "";
    property string pathText: "";
    //property bool showPathTree: false;

    header: PageHeader {
        title: i18n.tr("Browse")
    }

    function createDirUpContainer() {
        var nli = UPnP.createNewListItem("Container")
        nli.dtype = UPnP.DonnieItemType.ContentServer,
        nli.id = app.currentBrowseStack.peek().pid,
        nli.pid = "-2",
        nli.title = ".."
        nli.titleText = "..",
        nli.currentIndex = app.currentBrowseStack.peek().currentIndex
        return nli
    }

    Connections {
        target: upnp
        onBrowseDone: {
            var i

            try {

                //console.log(contentsJson)
                contents = JSON.parse(contentsJson)

                // no ".." for the root or if there already is one
                if(cid !== "0" && browseModel.count == 0) {
                    browseModel.append(createDirUpContainer())
                }

                for(i=0;i<contents.containers.length;i++) {
                    var container = contents.containers[i]
                    browseModel.append(UPnP.createListContainer(container))
                }

                for(i=0;i<contents.items.length;i++) {
                    var item = contents.items[i]
                    var upnpClass = item.properties["upnp:class"]
                    if(upnpClass && UPnP.startsWith(upnpClass, "object.item.audioItem")) {
                        browseModel.append(UPnP.createListItem(item))
                    } else
                        console.log("onBrowseDone: skipped loading of an object of class " + item.properties["upnp:class"]);
                }

                pathText = UPnP.getCurrentPathString(app.currentBrowseStack);
                //pathTreeText = UPnP.getCurrentPathTreeString(app.currentBrowseStack);

                totalCount = contents["totalCount"]

                // scroll to previous position
                if(cScrollIndex > -1 && cScrollIndex < browseModel.count) {
                    listView.positionViewAtIndex(cScrollIndex, ListView.Center)
                }

                app.saveLastBrowsingJSON()

            } catch( err ) {
                app.error("Exception in onBrowseDone: " + err);
                app.error("json: " + contentsJson);
            }

            showBusy = false;
        }

        onError: {
            if(cid !== "0" && browseModel.count == 0) { // no ".." for the root
                browseModel.append(createDirUpContainer())
            }
            pathText = UPnP.getCurrentPathString(app.currentBrowseStack)
            console.log("Browse::onError: " + msg)
            showBusy = false
        }
    }

    ListModel {
        id: browseModel
    }

    ListModel {
        id: pathListModel
    }

    ListView {
        id: listView
        model: browseModel

        anchors.fill: parent
        interactive: contentHeight > height
        spacing: units.dp(8)

        header: Column {
              x: app.paddingMedium
              y: x
              width: parent.width - 2*x

              Rectangle { width: parent.width; height: app.paddingMedium; color: app.bgColor; opacity: 1.0; }
              Label {
                  id: path
                  width: parent.width
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                  color: app.primaryColor
                  elide: Text.ElideLeft
                  text: pathText
                  MouseArea {
                      anchors.fill: parent
                      onClicked: pageStack.push(menuDialogComponent)
                  }
             }
             Rectangle { width: parent.width; height: app.paddingMedium; color: app.bgColor; opacity: 1.0; }
        }

        delegate: AdaptiveListItem {
            id: delegate

            x: app.paddingMedium
            width: parent.width - 2*x
            height: stuff.height

            Row {
                id: stuff
                spacing: app.paddingMedium
                width: parent.width
                height: Math.max(imageItem.height, labels.height)

                Image {
                  id: imageItem
                  width: sourceSize.width > 0 ? app.iconSizeMedium : 0
                  height: sourceSize.height > 0 ? app.iconSizeMedium : 0
                  fillMode: Image.PreserveAspectFit
                  anchors.verticalCenter: parent.verticalCenter
                  source: {
                      if(pid === "-2") // the ".." item
                          return "image://theme/up";
                      if(type === "Container") { //
                          if(albumArtURI && albumArtURI.length > 0)
                              return albumArtURI
                          else if(upnpclass == "object.container.album.musicAlbum")
                              return "image://theme/stock_music"
                          else
                              return "image://theme/folder-symbolic"
                      }
                      return ""
                  }
                }

                Column {
                    id: labels
                    width: parent.width - imageItem.width
                    anchors.verticalCenter: imageItem.verticalCenter

                    Item {
                        width: parent.width
                        height: tt.height

                        Label {
                            id: tt
                            color: app.primaryColor
                            textFormat: Text.StyledText
                            elide: Text.ElideRight
                            width: parent.width - dt.width
                            //font.pixelSize: app.fontPixelSizeMedium
                            text: titleText ? titleText : ""
                        }
                        Label {
                            id: dt
                            anchors.right: parent.right
                            color: app.secondaryColor
                            font.pixelSize: app.fontSizeSmall
                            text: durationText ? durationText : ""

                        }
                    }

                    Label {
                        color: app.secondaryColor
                        font.pixelSize: app.fontSizeSmall
                        textFormat: Text.StyledText
                        elide: Text.ElideRight
                        width: parent.width
                        visible: metaText ? (metaText.length > 0) : false
                        text: metaText ? metaText : ""
                    }
                }

            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    var item = listView.model.get(index)
                    if(item.pid === "-2") // the ".." item
                        popFromBrowseStack()
                    else if(item.type === "Container")
                        pushOnBrowseStack(item.id, item.pid, item.title, index);
                    if(item.type !== "Item") {
                        if(item.id !== "-1" )
                            cid = item.id
                        else // something went wrong
                            cid = "0"
                    }
                }
            }

            function openActionMenu() {
                listItemMenu.show(index)
            }
        }

        ScrollBar.vertical: ScrollBar {}
    }


    ListItemMenu {
        id: listItemMenu

        property ListView listView: listView

        actions: [
            Action {
                text: i18n.tr("Add To Player")
                onTriggered: getPlayerPage().addTracks([listView.model.get(listItemMenu.index)])
            },
            Action {
                text: i18n.tr("Replace in Player")
                onTriggered: getPlayerPage().replaceTracks([listView.model.get(listItemMenu.index)])
            },
            Action {
                text: i18n.tr("Add All To Player")
                onTriggered: getPlayerPage().addTracks(getAllTracks())
            },
            Action {
                text: i18n.tr("Replace All in Player")
                onTriggered: getPlayerPage().replaceTracks(getAllTracks())
            }
        ]
    }

    // from ComboBox.qml
    Component {
        id: menuDialogComponent

        Page {

            Component.onCompleted: {
                var menuItems = app.currentBrowseStack.elements();
                for (var i = 1; i <= menuItems.length; i++) {
                    var child = menuItems[menuItems.length-i];
                    items.append( {"item": child } );
                }
            }

            ListModel {
                id: items
            }

            ListView {
                id: view

                anchors.fill: parent
                model: items

                header: PageHeader {
                    title: i18n.tr("Choose A Path")
                }

                delegate: AdaptiveListItem {
                    id: delegateItem
                    x: app.paddingMedium
                    width: parent.width - 2*x
                    height: app.itemSizeMedium

                    Label {
                        id: path
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        elide: Text.ElideLeft
                        text: UPnP.getPathString(app.currentBrowseStack, model.item.id)
                        color: (delegateItem.highlighted || model.item === cid)
                               ? app.primaryColor
                               : app.secondaryColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            popFromBrowseStackUntil(model.item.id)
                            cid = item.id
                            cScrollIndex = item.currentIndex
                            pageStack.pop()
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {}
            }
        }
    }

    onCidChanged: {
        console.log("onCidChanged: " + cid)
        if(cid === "")
            return

        showBusy = true

        if(app.currentBrowseStack.empty()) {
            if(cid === "0") { // root
                pushOnBrowseStack(cid, "-1", i18n.tr("[Top]"), -1)
            } /*else {
                // probably arrived here from search page
                // so we have to 'create' a browse stack
                // BUT that option has been disabled
                createBrowseStackFor(cid)
                pathText = UPnP.getCurrentPathString(app.currentBrowseStack)
            }*/
        }

        browseModel.clear()
        browse(0)
    }

    function browse(start) {
        startIndex = start;
        upnp.browse(cid, start, maxCount);
    }

    function reset() {
        pathListModel.clear();
        app.currentBrowseStack.empty();
        cid = "";
        cScrollIndex = -1
    }

    function popFromBrowseStackUntil(id) {
        do {
            if(app.currentBrowseStack.peek().id === id)
                break;
            popFromBrowseStack();
        } while(app.currentBrowseStack.length()>0)
    }

    function popFromBrowseStack() {
        cScrollIndex = app.currentBrowseStack.peek().currentIndex;
        app.currentBrowseStack.pop();
        if(pathListModel.count > 1) {
            pathListModel.remove(0);
            //pathComboBoxIndex = -1;
        } else
            console.log("popFromBrowseStack too often")
    }

    function pushOnBrowseStack(id, pid, title, currentIndex) {
        app.currentBrowseStack.push( {id: id, pid: pid, title: title, currentIndex: currentIndex});
        pathListModel.insert(0, {id: id, pid: pid, title: title});
        //pathComboBoxIndex = -1;
    }

    function getAllTracks() {
        var tracks = [];
        for(var i=0;i<listView.model.count;i++) {
            if(listView.model.get(i).type === "Item")
                tracks.push(listView.model.get(i))
        }
        return tracks
    }

    /*function createBrowseStackFor(id) {
        var i;

        pushOnBrowseStack("0", "-1", "[Top]");
        var pathJson = upnp.getPathJson(id);
        try {
            var path = JSON.parse(pathJson);
            for(i=path.length-1;i>=0;i--)
                pushOnBrowseStack(path[i].id, path[i].pid, path[i].title);
        } catch( err ) {
            app.error("Exception in createBrowseStackFor: " + err);
            app.error("json: " + pathJson);
        }
    }*/

}

