#!/usr/bin/env python3
import pathlib, subprocess, sys, tempfile

packages=list(pathlib.Path('packages').glob('*.deb'))
if len(packages)!=1: raise SystemExit(f'expected one deb, got {len(packages)}')
deb=packages[0]
fields=subprocess.check_output(['dpkg-deb','-f',str(deb)],text=True)
parsed={}
for line in fields.splitlines():
    if ': ' in line:
        k,v=line.split(': ',1)
        if k in parsed: raise SystemExit(f'duplicate control field: {k}')
        parsed[k]=v
if parsed.get('Package')!='com.haoge.liquidass.clockrecovery': raise SystemExit('wrong package id')
if parsed.get('Architecture')!='iphoneos-arm64e': raise SystemExit('wrong package architecture')
listing=subprocess.check_output(['dpkg-deb','-c',str(deb)],text=True)
for name in ['LiquidAssClock.dylib','LiquidAssClock.plist','LiquidAssBackboardd.dylib','LiquidAssBackboardd.plist']:
    if name not in listing: raise SystemExit(f'missing package payload: {name}')
with tempfile.TemporaryDirectory() as tmp:
    subprocess.check_call(['dpkg-deb','-x',str(deb),tmp])
    root=pathlib.Path(tmp)/'Library/MobileSubstrate/DynamicLibraries'
    for stem in ['LiquidAssClock','LiquidAssBackboardd']:
        binary=root/(stem+'.dylib')
        arches=subprocess.check_output(['xcrun','lipo','-archs',str(binary)],text=True).split()
        if arches!=['arm64e']: raise SystemExit(f'{stem}: expected thin arm64e, got {arches}')
        plist=root/(stem+'.plist')
        subprocess.check_call(['plutil','-lint',str(plist)],stdout=subprocess.DEVNULL)
        txt=plist.read_text()
        expected='com.apple.springboard' if stem=='LiquidAssClock' else 'com.apple.backboardd'
        if expected not in txt: raise SystemExit(f'{stem}: incorrect process filter')
print(f'PASS: {deb} has one control field each, two thin arm64e dylibs and correct process filters')
