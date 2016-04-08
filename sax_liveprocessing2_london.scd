Master up samples
tweak greyhole settings add lfos
make more samples
2 mics
have fade in/out crescendos for fx

(s.options.numAudioBusChannels = 300;s.waitForBoot{fork{
	var ino,cch,bh,th,ma,switchAction,toggleAction,kvalsynth;
	var samps;
	var tmpbuf = s.sendMsg(\b_allocRead,99,"/home/user/Documents/liveprocessing-master/samples/saxsample.aif");
	var path = "/home/user/Documents/liveprocessing-master/";
	////Groups
	s.sendMsg(\g_new, 900, 1, 1);
	10.do{|ix| s.sendMsg(\g_new, 901+ix, 3, 900+ix)};
	////Samples
	s.sendMsg(\b_allocRead,0, path ++ "samples/iceCreamTruckmf.aif");
	s.sendMsg(\b_allocRead,1, path ++ "samples/Blackbird.aif");
	s.sendMsg(\b_allocRead,2, path ++ "samples/tambura.aif");
	s.sendMsg(\b_allocRead,3, path ++ "samples/unacorda.aif");
	s.sendMsg(\b_allocRead,4, path ++ "samples/mirdangamRoll1.aif");
	//SYNTH DEFS
	/*SynthDef(\template, {
	arg ibs,obs=0,atk=0.02,rel=0.1,crv= 0,gate=1;
	var src, sig, env, amp;
	amp = \amp.kr(0.85,0.01);
	env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
	src = In.ar(ibs);
	sig = FX(source);
	Out.ar(obs, sig*amp*env);
	}).add;*/
	SynthDef(\micin, {
	arg ibs=0,obs,atk=0.01,rel=0.1,crv= 0,gate=1;
	var sig, env, amp;
	amp = \amp.kr(0.85,0.01);
	env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
	sig = SoundIn.ar(ibs);
	Out.ar(obs, sig*amp*env);
	}).add;
	SynthDef(\playsamp_m, {
		arg ibs,obs=0,atk=0.02,rel=0.1,crv= 0,gate=1,buf,loop=1;
		var src, sig, env, amp;
		amp = \amp.kr(0.85,0.01);
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		sig = PlayBuf.ar(1, buf,loop:loop);
		Out.ar(obs, sig*amp*env);
	}).add;
	SynthDef(\playsamp_s, {
		arg ibs,obs=0,atk=0.02,rel=0.1,crv= 0,gate=1,buf,loop=1;
		var src, sig, env, amp;
		amp = \amp.kr(0.85,0.01);
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		sig = PlayBuf.ar(2, buf,loop:loop);
		Out.ar(obs, sig*amp*env);
	}).add;
	SynthDef(\route_s, {
		arg ibs,obs,atk=0.02,rel=0.1,crv= 0,gate=1;
		var src, sig, env, amp;
		amp = \amp.kr(0.85,0.01);
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		sig = In.ar(obs, 2);
		Out.ar(obs, sig*amp*env);
	}).add;
	SynthDef(\amplify, {
		arg ibs, obs=0, pobs, pobs2, gate=1;
		var src, sig, env, amp, sig2;
		amp = \amp.kr(0.85, 0.03);
		env = EnvGen.ar(Env.asr(releaseTime:0.01),gate,doneAction:2);
		src = In.ar(ibs);
		sig = src;
		sig2 = DelayC.ar(sig, 0.2, 0.05);
		Out.ar(pobs, [sig, sig2]*env*amp); //out to private (stereo) bus
		Out.ar(pobs2, [sig, sig2]*env*amp); //out to private (stereo) bus
		Out.ar(obs, [sig, sig2]*env*amp);
	}).add;
	SynthDef(\ampsamp, {
		arg ibs,sibs, obs=0,atk=0.02,rel=0.1,crv= 0,gate=1,loop=1,
		at=0.01,rt=0.01,inamp=1;
		var src, env, amp, samp, amptrack, mx;
		amp = \amp.kr(0.85,0.01);
		src = In.ar(ibs);
		amptrack = AmplitudeMod.kr(src*inamp,at,rt).poll;
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		//samp = PlayBuf.ar(2, buf,loop:loop);
		samp = In.ar(sibs, 2);
		Out.ar(obs, samp*amptrack*amp*env);
	}).add;
	SynthDef(\ringmod, {
		arg ibs1,ibs2,caramp=1, modamp=1,obs=0,atk=0.02,rel=0.1,crv= 0,gate=1;
		var car, mod1, mod2, sig1, sig2, env, amp;
		amp = \amp.kr(0.85,0.01);
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		car = In.ar(ibs1);
		mod1 = In.ar(ibs2);
		mod2 = In.ar(ibs2+1);
		sig1 = DiodeRingMod.ar(car*caramp, mod1*modamp);
		sig2 = DiodeRingMod.ar(car*caramp, mod2*modamp);
		Out.ar(obs, [sig1,sig2]*amp*env);
	}).add;
	SynthDef(\spectralvocoder, {
		arg ibs1, ibs2, inamp1=1, inamp2=1,obs=0, freeze = 0, mode=2.4,gate=1;
		var bufA, bufB, bufC, bufD, chain1a, chain1b, chain2a, chain2b, sig1, sig2, out1, out2, freq, amp, env;
		amp = \amp.kr(0.85, 0.05);
		env = EnvGen.ar(Env.asr(0.01, 1, 0.1),gate, doneAction:2);
		bufA = LocalBuf.new(2048);
		bufB = LocalBuf.new(2048);
		bufC = LocalBuf.new(2048);
		bufD = LocalBuf.new(2048);
		chain1a = FFT(bufA, In.ar(ibs1)*inamp1); // to be filtered
		chain2a = FFT(bufB, In.ar(ibs2)*inamp2);
		sig1 = PV_SpectralMap(chain1a, chain2a, 0.0, freeze, mode, 1);
		chain1b = FFT(bufC, In.ar(ibs1)*inamp1); // to be filtered
		chain2b = FFT(bufD, In.ar(ibs2+1)*inamp2);
		sig2 = PV_SpectralMap(chain1b, chain2b, 0.0, freeze, mode, 1);
		out1 = IFFT(sig1);
		out2 = IFFT(sig2);
		Out.ar(obs, [out1,out2]*env*amp);
	}).add;


	SynthDef(\tapedelay, {
		arg ibs, obs, rawobs, atk=0.02,rel=0.1,crv= 0,gate=1, damp=0, sz=1, md=0.1, mf=2,
		difffreq=0.1, difflo=0.2, diffhi=0.9,
		delfreq=0.1, dello=0, delhi=2,
		fbfreq=0.07, fblo=0.5, fbhi=0.77;
		var src, sig, env, amp, inamp, lfodiff, lfodel, lfofb;
		lfodiff = SinOsc.kr(difffreq).range(difflo, diffhi);
		lfodel = SinOsc.kr(delfreq).range(dello, delhi);
		lfofb = SinOsc.kr(fbfreq).range(fblo, fbhi);
		inamp = \inamp.kr(0.0, 0.01).dbamp;
		amp = \amp.kr(0,0.01).dbamp;
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		src = In.ar(ibs)*inamp;
		Out.ar(rawobs, src);
		sig = Greyhole.ar(src, lfodel, damp, sz, lfodiff, lfofb, md, mf);
		Out.ar(obs, sig*amp*env);
	}).add;

	SynthDef(\lpc, {
		arg caribs, modibs, caramp=1, modamp=1, obs, modobs, carobs, atk=0.02, rel=0.1, crv= 0, gate=1;
		var car, mod, mod2, sig, env, amp;
		caramp = \caramp.kr(0.0, 0.01).dbamp;
		modamp = \modamp.kr(0.0, 0.01).dbamp;
		amp = \amp.kr(0,0.01).dbamp;
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		car = In.ar(caribs, 2)*caramp;
		Out.ar(carobs, car);
		mod = In.ar(modibs, 2)*modamp;
		Out.ar(modobs, mod);
		sig = LPCAnalyzer.ar(car, mod);
		Out.ar(obs, sig*amp*env);
	}).add;


	1.1.wait;
	//SYNTHS
	////////Sample Play Synths
	s.sendMsg(\s_new, \playsamp_m, 10000, 0, 901, \obs, 100, \buf, 99, \amp, 1.5); //sax samp
	s.sendMsg(\s_new, \playsamp_s, 10001, 0, 902, \obs, 110, \buf, 0, \amp, 1.0); //icecream truck
	s.sendMsg(\s_new, \playsamp_s, 10002, 0, 902, \obs, 120, \buf, 1, \amp, 1.0); //blackbird
	s.sendMsg(\s_new, \playsamp_s, 10003, 0, 902, \obs, 130, \buf, 2, \amp, 1.0); //tambura
	s.sendMsg(\s_new, \playsamp_s, 10004, 0, 902, \obs, 140, \buf, 3, \amp, 1.0); //unacorda
	s.sendMsg(\s_new, \playsamp_s, 10005, 0, 902, \obs, 150, \buf, 4, \amp, 1.0); //mirdangamRoll1

	//LEGEND//
	////GROUPS 900-909
	////KVAL SYNTHS 3000s
	////CONTROL BUSSES 0-6
}/*end fork*/}/*end s.waitForBoot*/);


s.meter

//tapedelay
//120 blackbird
//150 mirdungam
s.sendMsg(\s_new, \tapedelay, 15000, 0, 903, \ibs, 100, \obs, 0, \rawobs, 99); //set in amp in dbs
s.sendMsg(\n_set, 15000, \lfofb, 0.03, \fblo, 0.5, \fbhi, 0.77);
s.sendMsg(\n_set, 15000, \obs, 200);
s.sendMsg(\n_free, 15000);
//lpc
s.sendMsg(\s_new, \lpc, 16000, 0, 904, \caribs, 200, \carobs, 43, \obs, 0, \modibs, 120, \modobs, 40);
s.sendMsg(\n_set, 16000, \carobs, 0, \caramp, -96);
s.sendMsg(\n_set, 16000, \modibs, 120, \modobs, 0, \modamp,-96);
s.sendMsg(\n_set, 16000, \obs, 47);
s.sendMsg(\n_free, 16000);

//play samples
s.sendMsg(\s_new, \ampsamp, 17000, 0, 903, \ibs, 100, \sibs, 110, \obs, 0);
s.sendMsg(\n_free, 17000);
//ampsamp
s.sendMsg(\s_new, \ampsamp, 11000, 0, 903, \ibs, 77, \sibs, 150, \obs, 0);
s.sendMsg(\n_set, 11000, \at, 0.01, \rt, 0.1, \inamp, 30, \amp, 5, \sibs, 150);//mdroll
s.sendMsg(\n_set, 11000, \at, 0.01, \rt, 0.1, \inamp, 20, \amp, 4, \sibs, 120);//birds
s.sendMsg(\n_free, 11000);
//spectral vocoder
s.sendMsg(\s_new, \spectralvocoder, 13000, 0, 903, \ibs1, 140, \ibs2, 100);
s.sendMsg(\n_set, 13000, \inamp1, 150, \inamp2, 1, \amp, 5, \mode, 1,  \ibs1, 120, \ibs2, 100);
s.sendMsg(\n_set, 13000, \inamp1, 1, \inamp2, 100, \amp, 2, \mode, 1.1,  \ibs1, 120, \ibs2, 100);
s.sendMsg(\n_set, 13000, \inamp1, 1, \inamp2, 100, \amp, 2, \mode, 100, \ibs2, 110);
s.sendMsg(\n_free, 13000);
//ringmod
s.sendMsg(\s_new, \ringmod, 14000, 0, 903, \ibs1, 100, \ibs2, 140);
s.sendMsg(\n_set, 14000, \caramp, 2, \modamp, 4, \amp, 1, \ibs1, 100, \ibs2, 130);
s.sendMsg(\n_set, 14000, \caramp, 3, \modamp, 2, \amp, 1, \ibs1, 100, \ibs2, 130);
s.sendMsg(\n_free, 14000);

//Mic In
s.sendMsg(\s_new, \micin, 16000, 0, 901, \ibs, 0, \obs, 77);
s.sendMsg(\n_free, 16000);

s.sendMsg(\n_set, 10000, \obs, 0);
s.sendMsg(\n_set, 10000, \obs, 100);
s.sendMsg(\n_set, 10001, \obs, 0);
s.sendMsg(\n_set, 10001, \obs, 101);
s.sendMsg(\n_set, 10002, \obs, 0);
s.sendMsg(\n_set, 10002, \obs, 102);


s.sendMsg(\s_new, \amplify, 12000, 0, 902, \ibs, 100, \obs, 0, \pobs, 150, \pobs2, 160);
s.sendMsg(\n_set, 12000, \amp, 0.2);
s.sendMsg(\n_free, 12000);

/*
USE LPC STRICTLY
MIX WITH ONE SHOT SAMPLE PLAYBACK
////MAKE MORE LPC SAMPLES
////MAKE SOME ONE SHOT SAMPLES - FREEZE VERSIONS
*/