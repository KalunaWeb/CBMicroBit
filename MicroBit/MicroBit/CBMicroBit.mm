//
// CBMicroBit.cpp
//
// Copyright 2017 Louis McCallum
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial
// portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//

#include "CBMicroBit.h"
#import "CBMicroBitBridge.h"
#import <Foundation/Foundation.h>
#include <iostream>
#include "oscpkt.hh"
#include "udp.hh"

using namespace oscpkt;

struct BLEImpl
{
    CBMicroBitBridge *wrapped;
};

CBMicroBit::CBMicroBit(int port, bool osc, bool wek):
impl(new BLEImpl)
{
    sendPort = port;
    wekinator = wek;
    impl->wrapped = [[CBMicroBitBridge alloc] initWithDataCallback:^(NSArray *data){
        std::string service = [data[0] UTF8String];
        if(service == "accelerometer")
        {
            int accData[3] = {[data[1] intValue], [data[2] intValue], [data[3] intValue]};
            if(osc && !wekinator) {
                sendAccData(accData);
            }
            aggData[0] = accData[0];
            aggData[1] = accData[1];
            aggData[2] = accData[2];
            if(osc && wekinator) {
                sendWekinatorData();
            }
        }
        else if (service == "buttonA")
        {
            int state = [data[1] intValue];
            if(osc && !wekinator) {
                sendButtonData(true, state);
            }
            aggData[3] = state;
        }
        else if (service == "buttonB")
        {
            int state = [data[1] intValue];
            if(osc && !wekinator) {
                sendButtonData(false, state);
            }
            aggData[4] = state;
        }
        else if (service == "pins")
        {
            int pinData[3] = {[data[1] intValue], [data[2] intValue], [data[3] intValue]};
            if(osc && !wekinator) {
                sendPinData(pinData);
            }
            aggData[5] = pinData[0];
            aggData[6] = pinData[1];
            aggData[7] = pinData[2];
        }
    } discoveryCallBack:^{
        std::cout << "did Find Micro:bit" << std::endl;
    } andConnectionCallback:^{
        std::cout << "did Connect To Micro:bit" << std::endl;
    }];
}

CBMicroBit::~CBMicroBit()
{
    std::cout << "destructor called" << std::endl;
    if (impl)
        [impl->wrapped cleanUp];
    delete impl;
}

void CBMicroBit::sendWekinatorData()
{
    UdpSocket sock;
    sock.connectTo("localhost", sendPort);
    Message msg("/wek/inputs");
    for(int i = 0; i < 8; i++)
    {
        msg.pushFloat((float)aggData[i]);
    }
    PacketWriter pw;
    pw.startBundle().startBundle().addMessage(msg).endBundle().endBundle();
    bool ok = sock.sendPacket(pw.packetData(), pw.packetSize());
    if(!ok)
    {
        std::cout << "osc failed to send" << std::endl;
    }
    sock.close();
}

void CBMicroBit::sendButtonData(bool buttonA, int state)
{
    UdpSocket sock;
    sock.connectTo("localhost", sendPort);
    Message msg(buttonA ? "/buttonA" : "/buttonB");
    msg.pushInt32(state);
    PacketWriter pw;
    pw.startBundle().startBundle().addMessage(msg).endBundle().endBundle();
    bool ok = sock.sendPacket(pw.packetData(), pw.packetSize());
    if(!ok)
    {
        std::cout << "osc failed to send" << std::endl;
    }
    sock.close();
}

void CBMicroBit::sendPinData(int data[3])
{
    UdpSocket sock;
    sock.connectTo("localhost", sendPort);
    Message msg("/pins");
    msg.pushDouble((double)data[0]);
    msg.pushDouble((double)data[1]);
    msg.pushDouble((double)data[2]);
    PacketWriter pw;
    pw.startBundle().startBundle().addMessage(msg).endBundle().endBundle();
    bool ok = sock.sendPacket(pw.packetData(), pw.packetSize());
    if(!ok)
    {
        std::cout << "osc failed to send" << std::endl;
    }
    sock.close();
}

void CBMicroBit::sendAccData(int data[3])
{
    UdpSocket sock;
    sock.connectTo("localhost", sendPort);
    Message msg("/acc");
    msg.pushInt32(data[0]);
    msg.pushInt32(data[1]);
    msg.pushInt32(data[2]);
    PacketWriter pw;
    pw.startBundle().startBundle().addMessage(msg).endBundle().endBundle();
    bool ok = sock.sendPacket(pw.packetData(), pw.packetSize());
    if(!ok)
    {
        std::cout << "osc failed to send" << std::endl;
    }
    sock.close();
}

