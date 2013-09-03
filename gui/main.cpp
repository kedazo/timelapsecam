#include "dialog.h"
#include <QApplication>

int main(int argc, char *argv[])
{
  QApplication a(argc, argv);
  Dialog w;

  w.fetch_webcaminfos();
  w.show();
  
  return a.exec();
}
