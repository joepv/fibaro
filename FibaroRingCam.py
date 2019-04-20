from ring_doorbell import Ring
import subprocess
import time

def connectToRingAPI():
    global myring
    global mypath
    myring = Ring('user@ring.com', 'password')
    mypath = '/home/joep/FibaroRingCam/'
    currenttime = time.strftime("%b %d %H:%M:%S")
    print ('{} Connected to ring: {}'.format(currenttime, myring.is_connected))

def pollForDing():
    global myring
    global mypath
    # Get last event from doorbell...
    doorbell = myring.doorbells[0]
    for event in doorbell.history(limit=1):
        lastEvent = str(event['created_at'])

    # Get last event from server...
    try:
        fh = open(mypath + 'lastevent.log', 'r')
        savedLastEvent = fh.read()
        if (lastEvent != savedLastEvent):
            downloadRecording = 'yes'
            currenttime = time.strftime("%b %d %H:%M:%S")
            print ('{} New event found at {}. Last event saved: {}'.format(currenttime, lastEvent, savedLastEvent))
        else:
            downloadRecording = 'no'
            currenttime = time.strftime("%b %d %H:%M:%S")
            print ('{} No new event found. Last event saved: {}'.format(currenttime, savedLastEvent))
    except FileNotFoundError:
        currenttime = time.strftime("%b %d %H:%M:%S")
        print ('{} No last event saved.'.format(currenttime))
        downloadRecording = 'yes'

    if (downloadRecording == 'yes'):
        currenttime = time.strftime("%b %d %H:%M:%S")
        print ('{} Downloading last recording...'.format(currenttime))
        with open(mypath + 'lastevent.log', 'w') as log_file:
            log_file.write(lastEvent)

        doorbell.recording_download(
            doorbell.history(limit=100, kind='ding')[0]['id'],
                             filename='mypath + 'last_ding.mp4',
                             override=True)

        currenttime = time.strftime("%b %d %H:%M:%S")
        print ('{} Download ready, create snapshot for Fibaro Home Center 2...'.format(currenttime))
        subprocess.call(['ffmpeg', '-ss', '00:00:01', '-i', mypath + 'last_ding.mp4', '-vframes', '1', '-q:v', '2', mypath + 'last_ding.jpg', '-y'])

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
