from ring_doorbell import Ring
import subprocess
import time
import requests

def connectToRingAPI():
    global myring
    myring = Ring('username', 'password')
    currenttime = time.strftime("%b %d %H:%M:%S")
    print ('{} Connected to ring: {}'.format(currenttime, myring.is_connected))

def pollForDing():
    global myring
    # Get last event from doorbell...
    doorbell = myring.doorbells[0]
    for event in doorbell.history(limit=1):
        lastEvent = str(event['created_at'])

    # Get last event from server...
    try:
        fh = open('/home/joep/FibaroRingCam/lastevent.log', 'r')
        savedLastEvent = fh.read()
        if (lastEvent != savedLastEvent):
            downloadRecording = 'yes'
            currenttime = time.strftime("%b %d %H:%M:%S")
            print ('{} New event found at {}. Last event saved: {}'.format(currenttime, lastEvent, savedLastEvent))
        else:
            downloadRecording = 'no'
            currenttime = time.strftime("%b %d %H:%M:%S")
            #print ('{} No new event found. Last event saved: {}'.format(currenttime, savedLastEvent))
    except FileNotFoundError:
        currenttime = time.strftime("%b %d %H:%M:%S")
        print ('{} No last event saved.'.format(currenttime))
        downloadRecording = 'yes'

    if (downloadRecording == 'yes'):
        currenttime = time.strftime("%b %d %H:%M:%S")
        print ('{} Downloading last recording in 60 seconds...'.format(currenttime))
        time.sleep(60)
        with open('/home/joep/FibaroRingCam/lastevent.log', 'w') as log_file:
            log_file.write(lastEvent)

        doorbell.recording_download(
            doorbell.history(limit=100, kind='ding')[0]['id'],
                             filename='/home/joep/FibaroRingCam/last_ding.mp4',
                             override=True)

        currenttime = time.strftime("%b %d %H:%M:%S")
        print ('{} Download ready, create snapshot for Fibaro Home Center 2...'.format(currenttime))
        subprocess.call(['ffmpeg', '-ss', '00:00:01', '-i', '/home/joep/FibaroRingCam/last_ding.mp4', '-vframes', '1', '-q:v', '2', '/home/joep/FibaroRingCam/last_ding.jpg', '-y'])
        url = "http://192.168.2.1:5005"
        payload = "ding=dong&dong=ding"
        r = requests.post(url, data=payload)

connectToRingAPI()
while True:
    try:
        pollForDing()
    except:
        currenttime = time.strftime("%b %d %H:%M:%S")
        print ('{} An error occured, reconnect to Ring servers in 120 seconds...'.format(currenttime))
        time.sleep(120)
        connectToRingAPI()
        pollForDing()
    time.sleep(15)
