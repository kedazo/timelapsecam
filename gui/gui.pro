QT       += core gui

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = timelapsecam-qt4
TEMPLATE = app

SOURCES += main.cpp \
           dialog.cpp

HEADERS  += dialog.h
FORMS    += dialog.ui

