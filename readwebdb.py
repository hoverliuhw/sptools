#!/usr/bin/env python
'''
name: readwebdb
desc.: retrive SPA data on web db
'''
from HTMLParser import HTMLParser
import urllib2
import sys
import zipfile
import os
import socket
import getpass
import re
import platform

class SpaPageParser(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self)
        self.has_epay = False
        self.flag = None
        self.href = None
        self.spa_data_url_list = []
    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            self.flag = 'a'
            for href, link in attrs:
                index = link.find('which=')
                if index >= 0:
                    self.spa_data_url_list.append(link)
                    if self.has_epay == False and link.find('EPAY') >= 0:
                        self.has_epay = True

    def handle_data(self, data):
        pass

class DownloadPageParser(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self)
        self.dest_dir = "."
    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            for href, link in attrs:
                self.zipfile = self.dest_dir + "/ALL.zip"
                flink = urllib2.urlopen(link)
                data = flink.read()
                fzip = open(self.zipfile, "wb")
                fzip.write(data)
                fzip.close()

                fzip = zipfile.ZipFile(self.zipfile, 'r')
                for fsql in fzip.namelist():
                    print("Extracting %s" % fsql)
                    fzip.extract(fsql, self.dest_dir)
                fzip.close()
                os.remove(self.zipfile)
    def handle_data(self, data):
        pass

class WebDBPageParser(HTMLParser):
    customer_list = ('Go_Malta',
        'Vodafone_UK',
        'Vodafone_Netherlands',
        'Vodafone_Hungary',
        'BSNL',
        'Vodafone_Italy',
        'Vodafone_Czech',
        'E-Plus_Service_GmbH',
        'Vodafone_Ghana',
        'Vodafone_Albania',
        'Vodafone_Portugal',
        'Vodafone_Ireland',
        'MobileOne',
        'Vodafone_Greece')
    dir_map = {'Go_Malta' : 'GOM',
        'Vodafone_UK' : 'VFUK',
        'Vodafone_Netherlands' : 'VFNL',
        'Vodafone_Hungary' : 'VFHU',
        'BSNL' : 'BSNL',
        'Vodafone_Italy' : 'VFI',
        'Vodafone_Czech' : 'VFCZ',
        'E-Plus_Service_GmbH' : 'Eplus',
        'Vodafone_Ghana' : 'VFGH',
        'Vodafone_Albania' : 'VFAL',
        'Vodafone_Portugal' : 'VFP',
        'Vodafone_Ireland' : 'VFIE',
        'MobileOne' : 'M1',
        'Vodafone_Greece' : 'VFGR'}
    data_url_template = "http://inuweb.ih.lucent.com/~jterpstr/cgi-bin/WebDB/webdb_make_psql.cgi?action=Continue&menu=SPA&spaname=SERVICE%20PACKAGE%20MANAGEMENT%20SUBMENU&db={0}&PATH=&log_count=1"

    def __init__(self):
        HTMLParser.__init__(self)
        self.flag = None
        self.href = None
        self.customer_db = dict()

    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            for href, link in attrs:
                if href == 'href' and link.find('db=') >= 0:
                    self.flag = 'a'
                    index = link.find('db=')
                    self.href = link[index + len('db=') : ]

    def handle_data(self, data):
        if self.flag == 'a':
            if data in WebDBPageParser.customer_list and not self.customer_db.has_key(data) and self.has_epay(self.href):
                self.customer_db[data] = self.href
            self.flag = None
            self.href = None

    @staticmethod
    def has_epay(db_name):
        spalist_url = WebDBPageParser.data_url_template.format(db_name)
        response = urllib2.urlopen(spalist_url)
        html_page = re.sub(r'message.*</FORM>"', '', response.read())
        page_parser = SpaPageParser()
        page_parser.feed(html_page)
        has_epay = page_parser.has_epay
        page_parser.close()
        return has_epay

    @staticmethod
    def post_download_process(dest_dir, orig_hostname):
        '''Add file header, replace hostname'''
        os_type = platform.system()
        realpath = os.path.realpath(dest_dir)
        if os_type != 'Linux':
            hostnamefile = open(realpath + "/HOSTNAME", 'w')
            hostnamefile.write(orig_hostname)
            hostnamefile.close()
            return

        os.system('sed -i "1ipsql -h pglocalhost -U scncraft <<!eof\\nBEGIN;" {0}/*.sql'.format(realpath))
        os.system('sed -i "\$aCOMMIT;\\n!eof" {0}/*.sql'.format(realpath))

        hostname = socket.gethostname().upper()
        is_mcas = False
        if hostname.endswith('0-0-1'):
            hostname[0 : -6]
            is_mcas = True
        os.system('sed -i "s/{0}/{1}/g" {2}/*.sql'.format(orig_hostname, hostname, realpath))
        os.system('ls {0}/*.sql > {1}/sql.list'.format(realpath, realpath))
        os.system('chmod 755 {0}/*'.format(realpath))

        if not is_mcas:
            return
        rcda ='client global rc table Diameter_Authorization_tbl'
        rcdiamfsm ='client fsm Diameter_PROT_FSM'
        rcdiamavp ='public rc table Diameter_AVP_Configuration_tbl'

        enwtpps = WebDBPageParser.getsqlresult('''psql -Uscncraft -At -c "select version_name from sa_name_map where spa_base='ENWTPPS'"''')
        if not os.path.exists('{0}/{1}.sql'.format(realpath, enwtpps)):
            return

        epay = enwtpps.replace('ENWTPPS', 'EPAY')
        sqlda = WebDBPageParser.getsqlresult('''psql -Uscncraft -At -c "select item from rcmenutbl where title='{0}' and parent='{1}'"'''.format(rcda, epay))
        sqldiamfsm = WebDBPageParser.getsqlresult('''psql -Uscncraft -At -c "select item from rcmenutbl where title='{0}' and parent='{1}'"'''.format(rcdiamfsm, epay))
        sqldiamavp = WebDBPageParser.getsqlresult('''psql -Uscncraft -At -c "select item from rcmenutbl where title='{0}' and parent='{1}'"'''.format(rcdiamavp, enwtpps))

        diamfsm_schema = WebDBPageParser.getsqlresult('''psql -Uscncraft -A -c "select * from {0}"'''.format(sqldiamfsm)).split('|')
        updfsm = '''psql -Uscncraft -At -c "update {0} set {1}='DM4', {2}='318'"'''.format(sqldiamfsm, diamfsm_schema[4], diamfsm_schema[5])
        insertda = '''psql -Uscncraft -At -c "insert into {0} values ('DIAMCL','4','377','Y','version2.clci.ipc@vodafone.com')"'''.format(sqlda)
        deleteavp = '''psql -Uscncraft -At -c "truncate table {0}"'''.format(sqldiamavp)

        sqllist = open(realpath + "/sql.list", 'a')
        sqllist.write(updfsm + os.linesep)
        sqllist.write(insertda + os.linesep)
        sqllist.write(deleteavp + os.linesep)
        sqllist.close()

    @staticmethod
    def getsqlresult(sql):
        result = os.popen(sql)
        line = result.readline().strip()
        result.close()
        return line

if __name__ == '__main__':
    web_db_url = "http://inuweb.ih.lucent.com/~jterpstr/cgi-bin/WebDB/webdb_make_psql.cgi"
    response = None
    try:
        response = urllib2.urlopen(web_db_url)
    except urllib2.HTTPError, e:
        print(e)
        username = raw_input("Firewall User Authentication, CSL username: ")
        passwd = getpass.getpass()
        passwd_mgr = urllib2.HTTPPasswordMgrWithDefaultRealm()
        passwd_mgr.add_password(None, web_db_url, username, passwd)
        handler = urllib2.HTTPBasicAuthHandler(passwd_mgr)
        opener = urllib2.build_opener(handler)
        urllib2.install_opener(opener)
        response = urllib2.urlopen(web_db_url)
    except urllib2.URLError, e:
        print("connection error: {0}, \n exit!!!".format(e))
        sys.exit(1)
    
    print("Analyzing WebDB, need a half minute ...")
    html = response.read()
    mainpage=WebDBPageParser()
    mainpage.feed(html)

    spa_parser = SpaPageParser()
    downloader = DownloadPageParser()
    downloader.dest_dir = "/home/ainet/hongwehl/site_data"
    #downloader.dest_dir = "D:/Python/data"

    customer = 'Vodafone_Italy'
    db_name = mainpage.customer_db[customer]
    print("customer: {0}, database: {1}".format(customer, db_name))
    data_url = WebDBPageParser.data_url_template.format(db_name)
    response = urllib2.urlopen(data_url)
    # because there is malformed tag in spa list page, so need remove those lines using re
    html = re.sub(r'message.*</FORM>"', '', response.read())
    spa_parser.feed(html)

    for spaurl in spa_parser.spa_data_url_list:
        downloadpage = urllib2.urlopen(spaurl).read()
        downloader.feed(downloadpage)
    #os.remove(downloader.zipfile)

    orig_hostname = db_name[0 : -13]
    if orig_hostname.endswith('-0-0'):
        orig_hostname = orig_hostname[0 : -4]
    orig_hostname = orig_hostname.upper()
    WebDBPageParser.post_download_process(downloader.dest_dir, orig_hostname)

    downloader.close()
    spa_parser.close()
    mainpage.close()
