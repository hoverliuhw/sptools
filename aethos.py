#!/usr/bin/env python

# This Aethos test script is a simulator for:
# 1) RMS Server
# 2) TCPIP Notification Server
# 3) SMPP Notification Server(SMSC)
#
# It is developed by CE tester, in order to provide more flexibility in testing
#
# usage:
#     aethos.py [-h] [-p port] [-r] [-s] [-t] [--help] [--port=<port>] [--rms] [--smpp] [--tcp]
#         -h, --help: show help
#         -p, --port: specify the port number to listen
#         -r, --rms: indicate this is an RMS server for recharge
#         -s, --smpp: indicate this is an SMPP server for notification
#         -t, --tcp: indicate this is a TCP server for notification
#
#    example:
#        ./aethos.py -p 6666 --rms
#        ./aethos.py -p 8050 --tcp
#        ./aethos.py -p 8050 --smpp
#
#    if no arguments, default is RMS server, port number is 6666
#
#    Note for RMS:
#        Before using, please update dict var's parameters by referring SPA's configuration
#        and you can configure recharge amount, delay, and return result in dict resp_var
#
#  Liu Hongwei
#      Created on 9/27/2016
#      Enhanced on 8/19/2017

import socket, sys, getopt
from SocketServer import TCPServer, ThreadingTCPServer, StreamRequestHandler, BaseRequestHandler
import traceback
import time
import struct

class RMSHandler(BaseRequestHandler):
    '''
    RMS Server simulator
    '''
    # var is a copy of SPA configuration on Surepay side, need update if different
    # recharge amount and other response parameters are in resp_var below
    var = {
        'GP.Send_Provider_ID_In_External_RCMS': False,
        'CP.Send_Service_Provider_In_External_RCMS': False,
        'FF.RCMS_32bit_SN': False, # BSNL is True, GOM, CAMGSM is False
        'FC.VAS_Scratch_Card_Feature_Enable_Flag': True, # GOM, CAMGSM is True
        'FC.Send_Combined_PIN_And_RCN_For_Val': False, # BSNL is True, GOM, CAMGSM is False
        'FC.Two_Stage_Validation_For_Scratch_Card': True,
        'RRI_Prefix': 'SCRATCH1',
        'Customer': ''
    }

    # AethosOpPrefix and AethosResultPrefix mapping
    # True means RCMS_32bit_SN_Flag is True, False means RCMS_32bit_SN_Flag is False
    resp_prefix = {
       "00350F".decode('hex'): {True: "004B10".decode('hex'), # Card_Reservation
                               False: "003B10".decode('hex')},
       "002A11".decode('hex'): {True: "000412".decode('hex'), # Cancel Reservation, True/False are the same
                               False: "000412".decode('hex')},
       "00350D".decode('hex'): {True: "004B0E".decode('hex'),
                               False: "003B0E".decode('hex')},
       "00200b".decode('hex'): {True: "004d0c".decode('hex'),
                               False: "003d0c".decode('hex')},
       "002009".decode('hex'): {True: "00350a".decode('hex'),
                               False: "00250a".decode('hex')},
       "001D05".decode('hex'): {True: "004a06".decode('hex'),
                               False: "003a06".decode('hex')},
       "001D07".decode('hex'): {True: "003208".decode('hex'),
                               False: "002208".decode('hex')},
       "001503".decode('hex'): {True: "002904".decode('hex'), # True/False are the same
                               False: "002904".decode('hex')},
       "001501".decode('hex'): {True: "001102".decode('hex'), # True/False are the same
                               False: "001102".decode('hex')}
    }
    
    # validationResult, this definition is got from SRD
    validate_result_code = {
        "afr_success": 0,
        "afr_no_such_card": 1, # 1 or 2, here we use 1
        "afr_card_used": 3,
        "afr_card_not_active": 4,
        "afr_card_expired": 5,
        "afr_invalid_provider_id": 6,
        "afr_card_reserved_by_other_user": 7,
        "afr_card_no_in_reserved_state": 8,
        "afr_card_already_reserved_by_the_user": 9,
        # "afr_parameter_error": 10,
        # "afr_invalid_provider_id": 11,
        "afr_card_is_rejected": 12,
        # "afr_card_used": 13,
        # "afr_connect_failure": 14,
        # "afr_card_reserved_by_other_user": 15,
        # "afr_Send_Cancel_For_Timeout": 18,
        "afr_invalid_request": 20,
        "afr_database_internal_error": 21,
        "afr_timeout_for_cancel": 25, # or Timeout Error
        "afr_database_system_fault": 26 # any other value bigger than 25
    }

    # response parameters, such as recharge amount, delay timer(in sec.)
    resp_var = {
        'validationResult': validate_result_code['afr_success'],
        'amount': 1000000,
        'serial_no_32': '00000000000000001200559400000065',
        'serial_no_16': '5315976452' + '\000'*6,
        'customer': var['Customer'],
        'card_type': var['RRI_Prefix'],
        'face_value': 1000000,
        'delay': 0
    }

    def handle(self):
        print("Start RMS Server")
        while True:
            try:
                data = self.request.recv(1024).strip()
                if not data:
                    continue
                AethosOpPrefix = data[0 : 3]
                printable_opcode = AethosOpPrefix.encode('hex')
                if AethosOpPrefix == "002A11".decode('hex'):
                    printable_opcode = printable_opcode + ' (* Card Cancel *)'
                elif AethosOpPrefix == "00350F".decode('hex'):
                    printable_opcode = printable_opcode + ' (* Card Reservation *)'
                else:
                    printable_opcode = printable_opcode + ' (* Card Recharge *)'

                print('*** Receive request, OpCode: %s' % printable_opcode)

                self.parse_card(data)

                RCMS_32bit_SN = self.var['FF.RCMS_32bit_SN']

                resp = self.resp_prefix[AethosOpPrefix][RCMS_32bit_SN] + self.response(data)
                time.sleep(self.resp_var['delay'])
                self.request.sendall(resp)
            except Exception, ex:
                # traceback.print_exc()
                break

    def parse_card(self, data):
        # AethosResultPrefix:     3 bytes,
        # len_account_id:     1 byte,
        # account_id:         8 bytes,
        # card_no_and_pin:    30 bytes
        # len_cardno:         1 byte,
        # card no:            8 bytes,
        # provider_id:        11 bytes, no need to decode
        # service provider:    8 bytes, currently, it is all '\000' in Surepay

        Send_Provider_ID_In_External_RCMS = self.var['GP.Send_Provider_ID_In_External_RCMS']
        Send_Service_Provider_In_External_RCMS = self.var['CP.Send_Service_Provider_In_External_RCMS']
        RCMS_32bit_SN = self.var['FF.RCMS_32bit_SN']
        VAS_Scratch_Card_Feature = self.var['FC.VAS_Scratch_Card_Feature_Enable_Flag']
        Send_Combined_PIN_And_RCN_For_Val = self.var['FC.Send_Combined_PIN_And_RCN_For_Val']

        len_account_id = int(data[3].encode('hex'), 16)
        account_id = data[4 : 12].encode('hex')
        account_id = account_id[0 : len_account_id]

        if Send_Combined_PIN_And_RCN_For_Val:
            # BSNL, cardno and pin occupy 30 bytes, and no need to decode
            card = data[12 : 42].replace('\000', '')
            cardno, cardpin = card.split(':', 2)

            # provider id occupies 11 bytes, no need to decode
            # in cancel message, there is no provider id
            if len(data) > 42:
                provider_id = data[42 : ].replace('\000', '')
            print('''            * Account ID: \t{0} 
            * Card ID: \t{1}
            * Card PIN: \t{2}\n'''.format(account_id, cardno, cardpin))
        elif Send_Provider_ID_In_External_RCMS:
            # written by referring to surepay code, not tested
            len_card = int(data[12].encode('hex'), 16)
            card = data[13 : 21].encode('hex')
            cardno = card[0 : len_card]

            # provider id occupies 11 bytes, no need to decode
            provider_id = data[21 : ].replace('\000', '')
            print('''            * Account ID: \t{0} 
            * Card ID: \t{1}
            * Provider ID: \t{2}\n'''.format(account_id, cardno, provider_id))
        elif Send_Service_Provider_In_External_RCMS:
            # written by referring to surepay code, not tested
            len_card = int(data[12].encode('hex'), 16)
            card = data[13 : 21].encode('hex')
            cardno = card[0 : len_card]

            # service provider occupies 8 bytes, currently is empty, so all are '\000'
            service_provider = data[21 : ].replace('\000', '')
            print('''            * Account ID: \t{0} 
            * Card ID: \t{1}
            * Service Provider: \t{2}(Should be empty)\n'''.format(account_id, cardno, service_provider))
        else:
            # GOM, cardno should occupy 8 bytes, padded with '\000'
            len_card = int(data[12].encode('hex'), 16)
            card = data[13 : ].encode('hex')
            cardno = card[0 : len_card]
            print('''            * Account ID: \t{0} 
            * Card ID: \t{1}\n'''.format(account_id, cardno))

    def response(self, data):
        # AethosOpPrefixResponse: 3 bytes
        # validationResult:	1 byte
        # recharge amount:	4 bytes
        # serial no.:	16/32 bytes
        # customer: 	0/9/10/11/13 bytes, this field is not defined, just mark it as customer or unknown
        # card type:	20 bytes, RRI prefix
        # face value:	4 bytes

        Send_Provider_ID_In_External_RCMS = self.var['GP.Send_Provider_ID_In_External_RCMS']
        Send_Service_Provider_In_External_RCMS = self.var['CP.Send_Service_Provider_In_External_RCMS']
        RCMS_32bit_SN = self.var['FF.RCMS_32bit_SN']
        VAS_Scratch_Card_Feature = self.var['FC.VAS_Scratch_Card_Feature_Enable_Flag']
        Send_Combined_PIN_And_RCN_For_Val = self.var['FC.Send_Combined_PIN_And_RCN_For_Val']
        Two_Stage_Validation_For_Scratch_Card = self.var['FC.Two_Stage_Validation_For_Scratch_Card']
        
        # if prefix is card reservation, validation result is 9, else default value(0)
        AethosOpPrefix = data[0 : 3]
        val_result = self.resp_var['validationResult'] if AethosOpPrefix != "00350F".decode('hex') else self.validate_result_code['afr_card_already_reserved_by_the_user']
        
        # is recharge or reservation(cancel reservation)
        is_rchg = not (AethosOpPrefix == "00350F".decode('hex') or AethosOpPrefix == "002A11".decode('hex'))

        amount = self.resp_var['amount']
        serial_no = self.resp_var['serial_no_32'] if RCMS_32bit_SN else self.resp_var['serial_no_16']
        customer = self.resp_var['customer']
        card_type = self.resp_var['card_type'] # used to check RRI tbl, current value is UPE1
        face_value = self.resp_var['face_value']
        
        # convert int to bytes using struct.pack
        val_result_s = struct.pack('b', val_result)
        amount_s = struct.pack('>i', amount)
        card_type = card_type + '\000' * (20 - len(card_type))
        face_value_s = struct.pack('>i', face_value)
        
        resp_suffix = val_result_s + amount_s
        
        # correspond to Surepay code:
        #   if (send_service_provider_id || send_service_provider) 
        #    ||(Feature_Configuration_tbl[1].Two_Stage_Validation_For_Scratch_Card
        #       && RMS_Two_Stage_Current_Step ==  Send_Card_Reservation)
        #    || Feature_Configuration_tbl[1].Send_Combined_PIN_And_RCN_For_Val
        if Send_Combined_PIN_And_RCN_For_Val or Send_Provider_ID_In_External_RCMS or Send_Service_Provider_In_External_RCMS or (Two_Stage_Validation_For_Scratch_Card and (not is_rchg)):
            resp_suffix = resp_suffix + serial_no

        # correspond to Surepay code:
        #   if Feature_Configuration_tbl[1].Send_Combined_PIN_And_RCN_For_Val
        #    || (Feature_Configuration_tbl[1].Two_Stage_Validation_For_Scratch_Card
        #        && RMS_Two_Stage_Current_Step ==  Send_Card_Reservation)
        len_unknown = len(customer)
        if Send_Combined_PIN_And_RCN_For_Val or (Two_Stage_Validation_For_Scratch_Card and (not is_rchg)):
            len_unknown = 11 # BSNL uses 11
        elif VAS_Scratch_Card_Feature:
            if Send_Provider_ID_In_External_RCMS:
                len_unknown = 13
            elif Send_Service_Provider_In_External_RCMS:
                len_unknown = 10
            else:
                len_unknown = 9 # GOM uses this, as 9, CAMGSM rchg uses 9, reserv uses 11
        resp_suffix = resp_suffix + customer + '\000' * (len_unknown - len(customer)) + card_type + face_value_s

        # in epay code, max len is 75 or 59, but here we haven't added AethosPrefixResponse(3 bytes)
        max_len = 72 if RCMS_32bit_SN else 56
        if len(resp_suffix) < max_len:
            resp_suffix = resp_suffix + '\000' * (max_len - len(resp_suffix))

        return resp_suffix

class TCPServerHandler(StreamRequestHandler):
    '''
    This class is to simulate TCP Server to receive TCPIP Notification
    It supports both asynchronous and synchronous method
    '''
    def handle(self):
        print("* connected by (%r)\n" % (self.client_address,))
        while True:
            try:
                data = self.rfile.readline().strip()
                if not data:
                   continue
                end = data.find('#')
                msg_id = data[0 : end + 1]
                msg = data[end + 1 :]
                print("******** receive message ********************************")
                print("* message id: {0}\n* message: {1}\n".format(msg_id, msg))
                self.wfile.write('ACK{0}'.format(msg_id))
            except:
                print("connection error, quit!")
                #traceback.print_exc()
                break


class SMPPHandler(StreamRequestHandler):
    '''
    SMPP Server simulator
    '''
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

    def handle(self):
        print("start smpp server")
        while True:
            try:
                data = self.request.recv(4)
                if not data:
                    continue
                    #break
                length = int(data.encode('hex'), 16)
                data = self.request.recv(length - 4)
                conn_type = data[0: 4]
                seq_no = data[8 : 12]

                if not self.resp_code.has_key(conn_type):
                    print('Invalid msg prefix %s' % conn_type.encode('hex'))
                    break

                if conn_type == self.ESME_BNDTRN:
                    self.handle_bind(data)
                elif conn_type == self.ESME_SUB_SM:
                    self.handle_sub_sm(data)
                elif conn_type == self.CANCEL_SM:
                    self.handle_cancel_sm(data)
                else:
                    print('Receive msg, msg prefix is %s\n' % conn_type.encode('hex'))

                # # sm esponse structure
                # length:	4 bytes
                # resp opcode:	4 bytes
                # resp result:	4 bytes
                # seq no:	4 bytes
                # msg id:	4 bytes
                resp = self.resp_code[conn_type] + self.ESME_ROK + seq_no + str(self.msgid)

                # convert length to 4 bytes using struct.pack
                len_resp = struct.pack('>i', len(resp) + 4)
                resp = len_resp + resp
                self.request.sendall(resp)
                self.msgid += 1
            except:
                traceback.print_exc()  
                break
    def handle_bind(self, data):
        # handle bind request
        # length:	4 bytes * cut before this function
        # opcode:	4 bytes
        # 4 x 1 null:	4 bytes
        # seq no.:	4 bytes
        # system id + null:	var
        # passwd + null:	var
        # system type + null:	var
        # interface version:	1 byte
        # addr_ton:	1 byte
        # addr_npi:	1 byte
        # address range + null:	var
        # 
        # data starts with connection type, bind in this function
        start = 0
        # four null bytes
        start = start + 4
        
        # sequence no.
        start = start + 4
        end = start + 4
        seq_no = int(data[start : end].encode('hex'), 16)

        # system id
        start = end
        end = data.find(self.NULL, start)
        system_id = data[start : end]

        # passwd
        start = end + 1
        end = data.find(self.NULL, start)
        # passwd = data[start : end]

        # system type
        start = end + 1
        end = data.find(self.NULL, start)
        # sys_type = data[start : end]

        # interface version
        start = end + 1
        # addr_ton
        start = start + 1
        # addr_npi
        start = start + 1

        # address range
        start = end + 1
        end = data.find(self.NULL, start)
        # addr_range = data[start : end]

        print("*> Bound by %s, %s" % self.client_address)
        print("* System id: %s\n" % system_id)

    def handle_sub_sm(self, data):
        # # submit sm
        # length:	4 bytes * cut before this function
        # opcode:	4 bytes
        # 4 x 1 null:	4 bytes
        # seq no.:	4 bytes
        # smpp service type + null:	var
        # source_addr_ton:	1 byte
        # source_addr_npi:	1 byte
        # source_addr + null:	var
        # dest_addr_ton:	1 byte
        # dest_addr_npi:	1 byte
        # dest_addr(msisdn) + null:	var
        # esm_class:	1 byte
        # protocol:	1 byte
        # priority:	1 byte
        # deliver time + null:	var
        # period + null:	var
        # registered delivery flag:	1 byte
        # replace if present flag:	1 byte
        # data coding:	1 byte
        # sm default msg id:	1 byte
        # len of msg:	1 byte
        # short msg content:	var
        #
        # * optional when segments
        # 020C:	2 bytes
        # 0002:	2 bytes
        # sar msg ref num:	2 bytes
        # 020E:	2 bytes
        # 0201:	2 bytes
        # sar total segments:	1 byte
        # 020F:	2 bytes
        # 0001:	2 bytes
        # sar segment seq:	1 byte
        #
        # data starts with connection type, submit_sm in this function
        start = 0
        # four null bytes
        start = start + 4

        # sequence no.
        start = start + 4
        end = start + 4
        seq_no = int(data[start : end].encode('hex'), 16)

        # smpp service type
        start = end
        end = data.find(self.NULL, start)

        # source_addr_ton, source_addr_npi
        start = end + 2

        # source_addr
        start = start + 1
        end = data.find(self.NULL, start)

        # dest_addr_ton, dest_addr_npi
        start = end + 2 

        # dest_addr(msisdn)
        start = start + 1
        end = data.find(self.NULL, start)
        msisdn = data[start : end]

        # esm_class
        start = end + 1
        # protocol number
        start = start + 1
        # priority
        start = start + 1

        # deliver time
        start = start + 1
        end = data.find(self.NULL, start)
        deliver_time = data[start : end]

        # period
        start = end + 1
        end = data.find(self.NULL, start)
        period = data[start : end]

        # registered_delivery_flag
        start = end + 1
        # replace_if_present_flag
        start = start + 1
        # data_coding
        start = start + 1
        # sm_default_msg_id
        start = start + 1

        # msg length
        start = start + 1
        msg_len = int(data[start].encode('hex'), 16)

        # msg content
        start = start + 1
        end = start + msg_len
        msg = data[start : end]

        # optional, only for segment messages
        start = end
        # print("* Sequence: %s\n* MSISDN: %s" % (seq_no, msisdn))
        if start == len(data):
        # Only one segment
            print("*> Submit SM\n* MSISDN: %s" % msisdn)
            print("* Message: %s\n" % msg)
        else:
        # Message is too long, so it is splitted into segments
            total_seg = int(data[-6].encode('hex'), 16)
            seg_num = int(data[-1].encode('hex'), 16)
            if seg_num == 1:
                print("*> Submit SM\n* MSISDN: %s" % msisdn)
            print("* Message(%d/%d): %s" % (seg_num, total_seg, msg))
            if seg_num == total_seg:
                print("\n")

    def handle_cancel_sm(self, data):
        # # cancel sm
        # length:	4 bytes cut before this function
        # opcode:	4 bytes
        # 4 x 1 null:	4 bytes
        # seq no.:	4 bytes
        # service type:	1 byte
        # msg id + null:	var
        # source addr ton:	1 byte
        # source addr npi:	1 byte
        # source addr + null:	var
        # dest addr ton:	1 byte
        # dest addr npi:	1 byte
        # dest addr:	1 byte(null)
        #
        # data starts with connection type, cancel_sm in this function
        start = 0
        # four null bytes
        start = start + 4
        
        # sequence no.
        start = start + 4
        end = start + 4
        seq_no = int(data[start : end].encode('hex'), 16)

        # service type 1 byte
        start = end

        # message id
        start = start + 1
        end = data.find(self.NULL, start)
        msg_id = data[start : end]

        # source_addr_ton, source_addr_npi
        start = end + 2

        # source_addr
        start = start + 1
        end = data.find(self.NULL, start)

        # dest_addr_ton, dest_addr_npi
        start = end + 2

        # dest_addr, it is 1 NULL in cancel message
        start = start + 1

        print("*> Cancel SM\n* Message ID: %s\n" % msg_id)

def usage():
    print('''usage:
    aethos.py [-h] [-p port] [-r] [-s] [-t] [--help] [--port=<port>] [--rms] [--smpp] [--tcp]
        -h, --help: show help
        -p, --port: specify the port number to listen
        -r, --rms: indicate this is an RMS server for recharge
        -s, --smpp: indicate this is an SMPP server for notification
        -t, --tcp: indicate this is a TCP server for notification

    example:
        ./aethos.py -p 6666 --rms
        ./aethos.py -p 8050 --tcp
        ./aethos.py -p 8050 --smpp

    if no arguments, default is RMS server, port number is 6666

    Note for RMS:
        Before using, please update dict var's parameters by referring SPA's configuration
        and you can configure recharge amount, delay, and return result in dict resp_var
    ''')

if __name__ == "__main__":
    if len(sys.argv) == 1:
         usage()
         sys.exit(1)

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
