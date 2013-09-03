#include "dialog.h"
#include "ui_dialog.h"

#include <QDir>
#include <QFileDialog>
#include <QDebug>
#include <QProcess>
#include <QStringListModel>

#ifdef DEVEL_BUILD
static const char *command = "./timelapsecam.sh";
#else
static const char *command = "/usr/bin/timelapsecam.sh";
#endif

Dialog::Dialog(QWidget *parent) :
  QDialog(parent),
  ui(new Ui::Dialog)
{
  ui->setupUi(this);
  ui->workingDir->setText (QDir::homePath());
}

Dialog::~Dialog()
{
  delete ui;
}

void Dialog::changeEvent(QEvent *e)
{
  QDialog::changeEvent(e);
  switch (e->type()) {
    case QEvent::LanguageChange:
      ui->retranslateUi(this);
      break;
    default:
      break;
  }
}

void Dialog::recalc_recLength ()
{
    int shotsPerMin = ui->shotsPerMinute->value ();
    int outLength = ui->outputLength->value ();
    int outFps = ui->outputFps->value ();

    int totalOutFrames = outFps * outLength;
    ui->recLength->blockSignals (true);
    // recLength is in 'minutes'
    ui->recLength->setValue (totalOutFrames / shotsPerMin);
    ui->recLength->blockSignals (false);

    generate_cmd ();
}

void Dialog::recalc_outLength ()
{
    int recLength = ui->recLength->value ();
    int shotsPerMin = ui->shotsPerMinute->value ();
    int outFps = ui->outputFps->value ();

    int totalRecFrames = recLength * shotsPerMin;
    ui->outputLength->blockSignals (true);
    // outputLength is in 'seconds'
    ui->outputLength->setValue (totalRecFrames / outFps);
    ui->outputLength->blockSignals (false);

    generate_cmd ();
}

void Dialog::on_shotsPerMinute_valueChanged(int arg1)
{
    Q_UNUSED(arg1);
    recalc_outLength ();
}

void Dialog::on_recLength_valueChanged(int arg1)
{
    Q_UNUSED(arg1);
    recalc_outLength ();
}

void Dialog::on_outputLength_valueChanged(int arg1)
{
    Q_UNUSED(arg1);
    recalc_recLength ();
}

void Dialog::on_outputFps_valueChanged(int arg1)
{
    Q_UNUSED(arg1);
    recalc_recLength ();
}

void Dialog::generate_cmd ()
{
    int recLength = ui->recLength->value ();
    int shotsPerMin = ui->shotsPerMinute->value ();
    int outFps = ui->outputFps->value ();

    m_cmd = QString (QString (command) + " -t %1 -o %2 -f %3 -d %4 -s %5 -c %6 -b %7 -w '%8'")
                     .arg (recLength)
                     .arg (outFps)
                     .arg (shotsPerMin)
                     .arg (m_webcamDev)
                     .arg (ui->captureSize->currentText())
                     .arg (ui->videoFormat->currentText())
                     .arg (ui->videoBitrate->value ())
                     .arg (ui->workingDir->text ());
    ui->cmdOutput->setText (m_cmd);
}

/**
 * A method to get the webcamera infos from timelapsecam.sh.
 *
 * Please note that this is a blocking method
 */
void Dialog::fetch_webcaminfos ()
{
    QProcess process;
    process.start (QString (command), QStringList () << "-i");
    if (! process.waitForStarted (-1)) {
        qWarning () << "timelapsecam.sh can't be started";
        return;
    }
    if (! process.waitForFinished (-1)) {
        qWarning () << "timelapsecam.sh error";
        return;
    }

    QByteArray result = process.readAll ();
    QString tosplit (QString::fromAscii(result.data()));
    process.close ();

    m_webcamdatas = tosplit.split("\n");

    QStringList webcamNames;
    foreach (QString data, m_webcamdatas) {
        QStringList infos = data.split(";");
        QString dev = infos.first().trimmed();
        QString name = infos.last().replace("\"", "").trimmed();
        if (dev.isEmpty ()) {
            continue;
        }
        webcamNames.append ("(" + dev + ") " +name);
    }
    QStringListModel *model = new QStringListModel (this);
    model->setStringList (webcamNames);
    ui->camera->setModel (model);
}

void Dialog::on_videoBitrate_valueChanged(int arg1)
{
    Q_UNUSED (arg1);
    generate_cmd ();
}

void Dialog::on_captureSize_currentIndexChanged(int index)
{
    Q_UNUSED (index);
    generate_cmd ();
}

void Dialog::on_camera_currentIndexChanged(int index)
{
    Q_UNUSED (index);
    Q_ASSERT (index < m_webcamdatas.size ());
    QStringList infos = m_webcamdatas.at(index).split(";");
    // set the camera then
    m_webcamDev = infos.first().trimmed();

    int width = infos.at(1).toInt ();
    int height = infos.at(2).toInt ();

    QStringList sizes;
    // 160x120 should be the smallest one
    while (width >= 160) {
        sizes.append (QString::number (width) + "x" + QString::number (height));
        width /= 2;
        height /= 2;
    }

    QStringListModel *model = new QStringListModel (this);
    model->setStringList (sizes);
    ui->captureSize->setModel (model);

    generate_cmd ();
}

void Dialog::on_videoFormat_currentIndexChanged(int index)
{
    Q_UNUSED (index);
    generate_cmd ();
}

void Dialog::on_pushButton_clicked()
{
    QProcess::startDetached ("xterm",
            QStringList () << "-hold" << "-e" << m_cmd);
}

void Dialog::on_wdchooser_clicked()
{
    QFileDialog chooser;
    chooser.setDirectory (ui->workingDir->text ());
    chooser.setFileMode (QFileDialog::Directory);
    chooser.setOption (QFileDialog::ShowDirsOnly, true);
    if (chooser.exec () == QDialog::Accepted) {
        ui->workingDir->setText (chooser.directory ().absolutePath ());
    }

    generate_cmd ();
}
