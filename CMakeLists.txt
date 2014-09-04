file(GLOB UDATA_QML_JS_FILES *.qml *.js)

# make the files visible in the qtcreator tree
add_custom_target(udata_QMlFiles ALL SOURCES ${UDATA_QML_JS_FILES})

install(FILES ${UDATA_QML_JS_FILES} DESTINATION ${APP_DIR}/udata)
