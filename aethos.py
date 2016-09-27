#!/usr/bin/env python

import socket, sys, getopt
from SocketServer import TCPServer, ThreadingTCPServer, StreamRequestHandler, BaseRequestHandler
import traceback

class TCPServerHandler(StreamRequestHandler):
    def handle(self):
        print("start tcp server")
	while True:
            try:
                data = self.rfile.readline().strip()
                print("receive from (%r):%r" % (self.client_address, data))
                self.wfile.write('ACK%s' % data)
            except:
                print("connection error: ")
                traceback.print_exc()
                break

class RMSHandler(BaseRequestHandler):
    def set_resp(self):
        RCMS_32bit_SN_Flag = True
        AethosOpPrefix = "00350F".decode('hex')
        if RCMS_32bit_SN_Flag:
            AethosResultPrefix = "004B10".decode('hex')
        else:
            AethosResultPrefix = "003B10".decode('hex')
        self.resp_prefix[AethosOpPrefix] = AethosResultPrefix
    
        # Cancel Reservation request code
        AethosOpPrefix = "002A11".decode('hex')
        AethosResultPrefix = "000412".decode('hex')
        self.resp_prefix[AethosOpPrefix] = AethosResultPrefix
    
        AethosOpPrefix = "00350D".decode('hex')
        if RCMS_32bit_SN_Flag:
            AethosResultPrefix = "004B0E".decode('hex')
        else:
            AethosResultPrefix = "003B0E".decode('hex')
        self.resp_prefix[AethosOpPrefix] = AethosResultPrefix
    
        AethosOpPrefix = "00200b".decode('hex')
        if RCMS_32bit_SN_Flag:
            AethosResultPrefix = "004d0c".decode('hex')
        else:
            AethosResultPrefix = "003d0c".decode('hex')
        self.resp_prefix[AethosOpPrefix] = AethosResultPrefix
    
        AethosOpPrefix = "002009".decode('hex')
        if RCMS_32bit_SN_Flag:
            AethosResultPrefix = "00350a".decode('hex')
        else:
            AethosResultPrefix = "00250a".decode('hex')
        self.resp_prefix[AethosOpPrefix] = AethosResultPrefix
    
        AethosOpPrefix = "001D05".decode('hex')
        if RCMS_32bit_SN_Flag:
            AethosResultPrefix = "004a06".decode('hex')
        else:
            AethosResultPrefix = "003a06".decode('hex')
        self.resp_prefix[AethosOpPrefix] = AethosResultPrefix
    
        AethosOpPrefix = "001D07".decode('hex')
        if RCMS_32bit_SN_Flag:
            AethosResultPrefix = "003208".decode('hex')
        else:
            AethosResultPrefix = "002208".decode('hex')
        self.resp_prefix[AethosOpPrefix] = AethosResultPrefix
    
        AethosOpPrefix = "001503".decode('hex')
        AethosResultPrefix = "002904".decode('hex')
        self.resp_prefix[AethosOpPrefix] = AethosResultPrefix
    
        AethosOpPrefix = "001501".decode('hex')
        AethosResultPrefix = "001102".decode('hex')
        self.resp_prefix[AethosOpPrefix] = AethosResultPrefix
    
    def handle(self):
        #print("\nRMS Server Start ...")
	self.resp_prefix = dict()
        self.set_resp()

        afr_success = 0
        afr_no_such_card = 1
        afr_card_used = 3
        afr_card_not_active = 4
        afr_card_expired = 5
        afr_invalid_provider_idset = 6
        afr_card_reserved_by_other_user = 7
        afr_fault_sending_recharge_card_check = 20
        afr_database_internal_error = 21
        afr_timeout_for_cancel = 25
        NULL = "00".decode('hex')

        validationResult = afr_success
        validationResult_s = str(hex(validationResult)).replace('0x', '')
        validationResult_s = '0' * (len(validationResult_s) % 2) + validationResult_s
        validationResult_s = validationResult_s.decode('hex')
        
        amount = 10000
        amount_s = str(hex(amount)).replace('0x', '')
        amount_s = '0' * (len(amount_s) % 2) + amount_s
        amount_s = amount_s.decode('hex')
        
        respsuffix = "00000000000000001200559400000065BSNL\000\000\000\000\000\000\000UPE1\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000'\020"

        while True:
            try:
		data = self.request.recv(1024).strip()
	        AethosOpPrefix = data[0 : 3]
                opcode = AethosOpPrefix.encode('hex')
                if AethosOpPrefix == "002A11".decode('hex'):
                    opcode = opcode + ' (* Cancel *)'
	        print('*** Receive request, OpCode: %s' % opcode)
                self.parse_card(data)
	        AethosResultPrefix = self.resp_prefix[AethosOpPrefix]
	        resp = AethosResultPrefix + validationResult_s + NULL * (4 - len(amount_s)) + amount_s + respsuffix
		self.request.sendall(resp)
            except Exception, ex:
                #traceback.print_exc()  
                break
    def parse_card(self, data):
        len_account_id = int(data[3].encode('hex'), 16)
        account_id = data[4 : 12].encode('hex')
        account_id = account_id[0 : len_account_id]
        card = data[12 : 42]
	card = card.replace('\000', '')
        cardno, cardpin = card.split(':', 2)
        print('''        * Account ID: \t{0} 
        * Card ID: \t{1}
        * Card PIN: \t{2}\n'''.format(account_id, cardno, cardpin))

class SMPPHandler(StreamRequestHandler):
    resp_code = dict()
    ESME_BNDTRN = "00000002".decode('hex')
    ESME_BNDTRN_RESP = "80000002".decode('hex')
    ESME_BNDTRXN = "00000009".decode('hex')
    ESME_BNDTRXN_RESP = "80000009".decode('hex')
    ESME_SUB_SM = "00000004".decode('hex')
    ESME_SUB_SM_RESP = "80000004".decode('hex')
    ENQUIRE_LINK = "00000015".decode('hex')
    ENQUIRE_LINK_RESP = "80000015".decode('hex')
    DATA_SM = "00000103".decode('hex')
    DATA_SM_RESP = "80000103".decode('hex')
    CANCEL_SM = "00000008".decode('hex')
    CANCEL_SM_RESP = "80000008".decode('hex')
    REPLACE_SM = "00000007".decode('hex')
    REPLACE_SM_RESP = "80000007".decode('hex')
    QUERY_SM = "00000003".decode('hex')
    QUERY_SM_RESP = "80000003".decode('hex')
	
    resp_code[ESME_BNDTRN] = ESME_BNDTRN_RESP
    resp_code[ESME_BNDTRXN] = ESME_BNDTRXN_RESP
    resp_code[ESME_SUB_SM] = ESME_SUB_SM_RESP
    resp_code[ENQUIRE_LINK] = ENQUIRE_LINK_RESP
    resp_code[DATA_SM] = DATA_SM_RESP
    resp_code[CANCEL_SM] = CANCEL_SM_RESP
    resp_code[REPLACE_SM] = REPLACE_SM_RESP
    resp_code[QUERY_SM] = QUERY_SM_RESP

    NULL = "00".decode('hex')
    GENERIC_NAK = "80000000".decode('hex')
    ESME_ROK = "00000000".decode('hex')
    ESME_RINVCMDID = "00000003".decode('hex')
    ESME_RINVCMDLEN = "00000002".decode('hex')
    msgid = 4485800000
    sm_start = 49

    def handle(self):
        #print("start smpp server")
        while True:
            try:
                data = self.request.recv(4)
                if not data:
                    break
                length = int(data.encode('hex'), 16)
                data = self.request.recv(length - 4)
                conn_type = data[0: 4]
                seq_no = data[8 : 12]

                if not self.resp_code.has_key(conn_type):
                    print('Invalid msg prefix %s' % conn_type.encode('hex'))
                    break

                if conn_type == self.ESME_BNDTRN:
                    print("Connected by %s, %s\n" % self.client_address)
                elif conn_type == self.ESME_SUB_SM and len(data) > self.sm_start:
                    sm_len = int(data[self.sm_start - 1].encode('hex'), 16)
                    msg = data[self.sm_start : self.sm_start + sm_len]
                    if len(data) == (self.sm_start + sm_len):
                        print("* Message: %s" % msg)
                    else:
                        total_seg = int(data[-6].encode('hex'), 16)
                        seg_num = int(data[-1].encode('hex'), 16)
                        print("* Message(%d/%d): %s" % (seg_num, total_seg, msg))
                        if seg_num == total_seg:
                            print("\n")
                elif conn_type == self.CANCEL_SM:
                    print("Cancel SM is received\n")
                else:
                    print('Receive msg, msg prefix is %s\n' % conn_type.encode('hex'))

                resp = self.resp_code[conn_type] + self.ESME_ROK + seq_no + str(self.msgid)
                len_resp = hex(len(resp) + 4)[2:]
                len_resp = '0' * (8 - len(len_resp)) + len_resp
                resp = len_resp.decode('hex') + resp
                self.request.sendall(resp)
                self.msgid += 1
            except:
                traceback.print_exc()  
                break

def usage():
    print('''usage:  
    aethos.py [-h] [-p port] [-r] [-s] [-t] [--help] [--port=<port>] [--rms] [--smpp] [--tcp]
        -h, --help: show help
        -p, --port: specify the port number to listen
        -r, --rms: indicate this is an RMS server for recharge
        -s, --smpp: indicate this is an SMPP server for notification
        -t, --tcp: indicate this is a TCP server for notification
    if no arguments, default is RMS server, port number is 6666
    example:
        ./aethos.py -p 6666 --rms
        ./aethos.py -p 8050 --tcp
        ./aethos.py -p 8050 --smpp
    ''')

if __name__ == "__main__":
    host = "" 
    port = 6666 
    #request_handler = TCPServerHandler
    #request_handler = SMPPHandler
    request_handler = RMSHandler

    try:
        opts, args = getopt.getopt(sys.argv[1 : ], 'hp:rst', ['help', 'port=', 'rms', 'smpp', 'tcp'])
    except getopt.GetoptError, e:
        print(e)
        usage()
        sys.exit(1)

    for opt, value in opts:
        if opt in ('-h', '--help'):
            usage()
            sys.exit(0)
        if opt in ('-p', '--port'):
            port = int(value)
        if opt in ('-r', '--rms'):
            request_handler = RMSHandler
        if opt in ('-s', '--smpp'):
            request_handler = SMPPHandler
        if opt in ('-t', '--tcp'):
            request_handler = TCPServerHandler
    addr = (host, port)  
      
    server = ThreadingTCPServer(addr, request_handler)  
    server.serve_forever()  
    
