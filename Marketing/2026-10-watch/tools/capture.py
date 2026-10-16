from pathlib import Path
import subprocess,time,signal
root=Path(__file__).resolve().parents[1]
udid='E5D91884-2515-4277-8528-F26E8269B328';bundle='com.count.kcal.app.watch'
# Start the recorder before launch so slow Watch capture startup cannot miss
# the first animation. Keep the complete sequence within one clock minute.
seconds=time.localtime().tm_sec
if seconds>29:time.sleep(61-seconds)
rec=subprocess.Popen(['xcrun','simctl','io',udid,'recordVideo','-f','--codec=hevc','--mask=ignored',str(root/'captures/watch-native-auto.mov')],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
started=False
for line in rec.stdout:
 print(line.strip(),flush=True)
 if 'Recording started' in line:started=True;break
if not started:raise RuntimeError('Simulator recording did not start')
subprocess.run(['xcrun','simctl','terminate',udid,bundle],capture_output=True)
subprocess.run(['xcrun','simctl','launch',udid,bundle,'--marketing-capture','-AppleLanguages','(en)','-AppleLocale','en_US'],check=True)
time.sleep(20)
rec.send_signal(signal.SIGINT)
rec.communicate(timeout=15)
if rec.returncode!=0:raise RuntimeError(f'Simulator recorder exit {rec.returncode}')
print('Recorded both native transitions.',flush=True)
