#!/usr/bin/python3
# -*- coding: utf-8 -*-
from __future__ import print_function


import os
import sys
import argparse
import configparser
import pathlib
import pymysql # pip install PyMySQL
import datetime
import arrow # pip install arrow
from ffmpy import FFmpeg # pip install ffmpy
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

class G:
    config = None
    def loadargs():
        sysargs = argparse.ArgumentParser(
            description = 'Script that injects call recordings into the production database'
        )
        sysargs.add_argument(
            '--configfile',
            nargs = 1,
            required = True,
            help = "Location of configuration file"
        )
        sysargs.add_argument(
            '--infile',
            nargs = 1,
            required = True,
            help = "Input File"
        )
        sysargs.add_argument(
            '--outfile',
            nargs = 1,
            required = True,
            help = "Output File"
        )
        sysargs.add_argument(
            '--starttime',
            nargs = 1,
            required = True,
            help = "Call start time"
        )
        sysargs.add_argument(
            '--endtime',
            nargs = 1,
            required = True,
            help = "Call end time"
        )
        sysargs.add_argument(
            '--agent',
            nargs = 1,
            required = True,
            help = "Agent Username"
        )
        sysargs.add_argument(
            '--agentid',
            nargs = 1,
            required = True,
            help = "Agent ID"
        )
        sysargs.add_argument(
            '--direction',
            nargs = 1,
            required = True,
            help = "Direction Flag"
        )
        sysargs.add_argument(
            '--csn',
            nargs = 1,
            required = True,
            help = "Call sequence number"
        )
        sysargs.add_argument(
            '--ani',
            nargs = 1,
            required = True,
            help = "Call ANI"
        )
        sysargs.add_argument(
            '--dnis',
            nargs = 1,
            required = True,
            help = "Call DNIS"
        )
        sysargs.add_argument(
            '--uuid',
            nargs = 1,
            required = True,
            help = "Call UUID"
        )
        sysargs.add_argument(
            '--paused',
            nargs = 1,
            required = True,
            help = "Paused Flag"
        )
        sysargs.add_argument(
            '--clientid',
            nargs = 1,
            required = True,
            help = "Client account number"
        )
        sysargs.add_argument(
            '--location',
            nargs = 1,
            help = "Location Data (optional)"
        )
        return sysargs.parse_args()
            
def parseconfig(configdata):
    configarr = {}
    configp = configparser.ConfigParser()
    configp.read_file(open(configdata))
    if not configp.has_option('MySQL', 'hostname'):
        raise Exception("MySQL hostname undefined")
    else:
        configarr['dbhost'] = configp['MySQL']['hostname']
    if not configp.has_option('MySQL', 'username'):
        raise Exception("MySQL username undefined")
    else:
        configarr['dbuser'] = configp['MySQL']['username']
    if not configp.has_option('MySQL', 'password'):
        raise Exception("MySQL password undefined")
    else:
        configarr['dbpass'] = configp['MySQL']['password']
    if not configp.has_option('MySQL', 'dbname'):
        raise Exception("MySQL database name undefined")
    else:
        configarr['dbname'] = configp['MySQL']['dbname']
    if not configp.has_option('MySQL', 'table'):
        raise Exception("MySQL table name undefined")
    else:
        configarr['dbtable'] = configp['MySQL']['table']
    if not configp.has_option('Notification', 'enabled'):
        configarr['notification'] = 'false'
    else:
        configarr['notification'] = configp['Notification']['enabled']
    if configarr['notification'] == 'false':
        return configarr
    if not configp.has_option('Notification', 'fromaddr'):
        raise Exception("Notification From: email address undefined")
    else:
        configarr['fromaddr'] = configp['Notification']['fromaddr']
    if not configp.has_option('Notification', 'toaddr'):
        raise Exception("Notification To: email address undefined")
    else:
        configarr['toaddr'] = configp['Notification']['toaddr']
    if not configp.has_option('Notification', 'smtpserver'):
        raise Exception("Notification SMTP server undefined")
    else:
        configarr['smtpserver'] = configp['Notification']['smtpserver']
    if not configp.has_option('Notification', 'smtpport'):
        configarr['smtpport'] = '25'
    else:
        configarr['smtpport'] = configp['Notification']['smtpport']
    if not configp.has_option('Notification', 'smtptls'):
        configarr['smtptls'] = 'false'
    else:
        configarr['smtptls'] = configp['Notification']['smtptls']
    if not configp.has_option('Notification', 'smtpauth'):
        configarr['smtpauth'] = 'false'
    else:
        configarr['smtpauth'] = configp['Notification']['smtpauth']
    if not configp.has_option('Notification', 'smtpuser') and configarr['smtpauth'] != 'false':
        raise Exception("Notification SMTP username undefined")
    elif configp.has_option('Notification', 'smtpuser'):
        configarr['smtpuser'] = configp['Notification']['smtpuser']
    if not configp.has_option('Notification', 'smtppass') and configarr['smtpauth'] != 'false':
        raise Exception("Notification SMTP password undefined")
    elif configp.has_option('Notification', 'smtppass'):
        configarr['smtppass'] = configp['Notification']['smtppass']
    return configarr

def sendemail(subj, message, dbconfig):
    tolist = dbconfig['toaddr'].replace(
        ", ",
        ",").split(
            ","
        )
    msg = MIMEMultipart(
        'alternative'
    )
    msg['Subject'] = subj
    msg['From'] = dbconfig['fromaddr']
    msg['To'] = dbconfig['toaddr']
    body = MIMEText(
        message,
        'plain'
    )
    msg.attach(
        body
    )
    server = smtplib.SMTP(
        dbconfig['smtpserver'],
        dbconfig['smtpport']
    )
    server.ehlo()
    if dbconfig['smtptls'] != 'false':
        try:
            server.starttls()
        except (Exception) as e:
            print("Couldn't start TLS: {}".format(e))
    if dbconfig['smtpauth'] != 'false':
        try:
            server.login(
                dbconfig['smtpuser'],
                dbconfig['smtppass']
            )
        except (Exception) as e:
            print("Couldn't authenticate to SMTP server: {}".format(e))
    server.set_debuglevel(10)
    try:
        server.sendmail(
            dbconfig['fromaddr'],
            tolist,
            msg.as_string()
        )
    except Exception as e:
        print("Couldn't send email: {}".format(e))
    server.quit()

def dbconn(dbconfig):
    connection = pymysql.connect(
        host = dbconfig['dbhost'],
        user = dbconfig['dbuser'],
        password = dbconfig['dbpass'],
        db = dbconfig['dbname']
    )
    return connection

def dbinsert(dbconfig, loadconfig):
    sql = """INSERT INTO {}
            (
                Station,
                ClientID,
                InboundFlag,
                DNIS,
                ANI,
                CSN,
                AgentLoginID,
                AudioFilePath,
                LoggerDate,
                AccessTime,
                UniqueID,
                Paused
            ) VALUES
            (
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s,
                %s
            )
    """.format(dbconfig['dbtable'])
    if int(loadconfig.paused[0]) > 0:
        paused = 1
    else:
        paused = 0
    starttime = arrow.get(
        loadconfig.starttime[0]
    )
    starttime = starttime.to('local')
    endtime = arrow.get(
        loadconfig.endtime[0],
    )
    starttime = starttime.to('local')
    accesstime = (endtime - starttime).total_seconds()
    try:
        conn = dbconn(dbconfig)
        with conn.cursor() as cur:
            cur.execute(
                sql,
                (
                    int(loadconfig.agentid[0]),
                    int(loadconfig.clientid[0]),
                    "{}".format(loadconfig.direction[0].upper()),
                    "{}".format(loadconfig.dnis[0]),
                    "{}".format(loadconfig.ani[0]),
                    "{}".format(loadconfig.csn[0]),
                    "{}".format(loadconfig.agent[0]),
                    "{}".format(loadconfig.outfile[0]),
                    "{}".format(starttime.strftime("%Y-%m-%d %H:%M:%S.%f")),
                    int(accesstime),
                    "{}".format(loadconfig.uuid[0]),
                    int(paused),
                )
            )
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        if dbconfig['notification'] != 'false':
            subj = "!!!ERROR - UNABLE TO INSERT RECORDING FOR CSN {}!!!".format(
                loadconfig.csn[0]
            )
            msg = "Unable to insert recording into database: {}\r\n\r\nThe following metadata is associated with this recording:\r\n\r\nAgent ID: {}\r\nClient ID: {}\r\nDirection: {}\r\nDNIS: {}\r\nANI: {}\r\nCSN: {}\r\nAgent: {}\r\nOutfile: {}\r\nStart Time: {}\r\nDuration: {}\r\nUUID: {}\r\nPaused: {}".format(
                e,
                loadconfig.agentid[0],
                loadconfig.clientid[0],
                loadconfig.direction[0].upper(),
                loadconfig.dnis[0],
                loadconfig.ani[0],
                loadconfig.csn[0],
                loadconfig.agent[0],
                loadconfig.outfile[0],
                starttime.strftime("%Y-%m-%d %H:%M:%S.%f"),
                accesstime,
                loadconfig.uuid[0],
                paused
            )
            sendemail(subj, msg, dbconfig)
        raise Exception(e)
        return False

def transcode(loadconfig, dbconfig):
    ff = FFmpeg(
        inputs = {
            loadconfig.infile[0]: None
        },
        outputs = {
            loadconfig.outfile[0]: [
                '-y',
                '-hide_banner',
                '-loglevel',
                'error',
                '-c:a',
                'libmp3lame',
                '-ac',
                '1',
                '-b:a',
                '16k',
                '-ar',
                '8000',
                '-metadata',
                'title="CSN: {}"'.format(
                    loadconfig.csn[0]
                ),
                '-metadata',
                'album="CSN: {} ANI: {} DNIS: {}"'.format(
                    loadconfig.csn[0],
                    loadconfig.ani[0],
                    loadconfig.dnis[0]
                ),
                '-metadata',
                'artist="{}"'.format(
                    str(loadconfig.agent[0])
                )
			]
        }
    )
    try:
        ff.run()
    except Exception as e:
        print("Unable to transcode file: {}".format(e))
        if dbconfig['notification'] != 'false':
            subj = "!!!ERROR - UNABLE TO TRANSCODE RECORDING FOR CSN {}!!!".format(
                loadconfig.csn[0]
            )
            mesg = "Unable to transcode file: {}\r\n\r\nCall Info:\r\n{}".format(
                e,
                loadconfig
            )
            sendemail(subj, mesg, dbconfig)
        return False
    if os.path.exists(loadconfig.outfile[0]):
        #os.remove(loadconfig.infile[0])
        return True
    return False

def main():
    loader = G.loadargs()
    config = parseconfig(loader.configfile[0])
    if not transcode(loader, config):
        raise Exception("Was not able to transcode file!")
    dbinsert(config, loader)
    return 0

if __name__ == "__main__":
    sys.exit(main())
