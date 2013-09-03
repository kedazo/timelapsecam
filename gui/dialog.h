#ifndef DIALOG_H
#define DIALOG_H

#include <QDialog>
#include <QString>
#include <QStringList>

namespace Ui {
  class Dialog;
}

class Dialog : public QDialog
{
  Q_OBJECT
  
public:
  explicit Dialog(QWidget *parent = 0);
  ~Dialog();
  
protected:
  void changeEvent(QEvent *e);

public slots:
  void fetch_webcaminfos ();
  
private slots:
  void on_outputLength_valueChanged(int arg1);
  void on_outputFps_valueChanged(int arg1);
  void on_recLength_valueChanged(int arg1);
  void on_shotsPerMinute_valueChanged(int arg1);

  void on_videoBitrate_valueChanged(int arg1);
  void on_captureSize_currentIndexChanged(int index);
  void on_camera_currentIndexChanged(int index);
  void on_videoFormat_currentIndexChanged(int index);

  void on_pushButton_clicked();

  void on_wdchooser_clicked();

private:
  void recalc_recLength ();
  void recalc_outLength ();
  void generate_cmd ();

private:
  Ui::Dialog   *ui;
  QString	  	 m_cmd;
  QStringList   m_webcamdatas;

  // for the command
  QString       m_webcamDev;
  QString       m_captureSize;
};

#endif // DIALOG_H
