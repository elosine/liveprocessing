

( s.options.numAudioBusChannels = 1000; s.waitForBoot{ fork{

	var path = "/Users/jyang/GitHub/liveprocessing/samples/";
	~proc = NetAddr("127.0.0.1", 12321);
	s.sendMsg(\b_allocRead, 99,  path ++ "saxsample.aif"); //sax sample proxy for live input
	////Groups
	s.sendMsg(\g_new, 900, 1, 1);
	10.do{|ix| s.sendMsg(\g_new, 901+ix, 3, 900+ix)};
	////Samples
	s.sendMsg(\b_allocRead,0, path ++ "iceCreamTruckmf.aif");
	s.sendMsg(\b_allocRead,1, path ++ "Blackbird.aif");
	s.sendMsg(\b_allocRead,2, path ++ "tambura.aif");
	s.sendMsg(\b_allocRead,3, path ++ "unacorda.aif");
	s.sendMsg(\b_allocRead,4, path ++ "mirdangamRoll1.aif");

	SynthDef(\phasorclock, {
		arg dur=10.0, start=0, end=1, abus=99, kbus, t_tr=0, pos=0;
		var index, indexnorm;
		index = Phasor.ar( t_tr, 1.0/(44100.0*dur), start, end, pos );
		Out.ar(abus, index);
		Out.kr(kbus, index);
	}).add;

	SynthDef(\timerobj, {
		arg ibs, st, end, aobs, kobs;
		var in,env,tr;
		in = In.ar(ibs);
		tr = (in>st)*(in<end);
		env = EnvGen.ar(Env.asr(0.0, 1, 0.0, 0),tr);
		Out.ar(aobs, in*env);
		Out.kr(kobs, in*env);
	}).add;
	SynthDef(\micin, {
		arg inch=0,obs,atk=0.01,rel=0.1,crv= 0,gate=1;
		var sig, env, amp;
		amp = \amp.kr(0.0,0.01).dbamp;
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		sig = SoundIn.ar(inch);
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
		arg ibs, obs, obs2, atk=0.02,rel=0.1,crv= 0,gate=1, damp=0, sz=1, md=0.1, mf=2,
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
		sig = Greyhole.ar(src, lfodel, damp, sz, lfodiff, lfofb, md, mf);
		Out.ar(obs, sig*amp*env);
		Out.ar(obs2, sig*amp*env);
	}).add;

	SynthDef(\lpc, {
		arg caribs, modibs, obs, modobs, carobs, atk=0.02, rel=0.1, crv= 0, gate=1;
		var car, mod, mod2, sig, env, amp, caramp, modamp;
		caramp = \caramp.kr(0.0, 0.01).dbamp;
		modamp = \modamp.kr(0.0, 0.01).dbamp;
		amp = \amp.kr(0, 0.01).dbamp;
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate, doneAction:2 );
		car = In.ar(caribs, 2)*caramp;
		Out.ar(carobs, car);
		mod = In.ar(modibs, 2)*modamp;
		Out.ar(modobs, mod);
		sig = LPCAnalyzer.ar(car, mod);
		Out.ar(obs, sig*amp*env);
	}).add;

	//OSC DEFS

	////Mechanism for Processing to grab control data
	OSCdef( \getkdata, {
		arg msg;
		var kbus = msg[1].asInteger;
		s.sendMsg(\c_get, kbus);
	}, "/getkdata");

	OSCdef( \kdat, {
		arg msg;
		var bnum=msg[1].asInteger;
		var val=msg[2].asFloat;
		~proc.sendMsg("/kdat", bnum, val);
	}, \c_set);

	OSCdef( \timer, {
		arg msg;
		var ix = msg[1].asInteger;
		var st=msg[2].asFloat;
		var end=msg[3].asFloat;
		s.sendMsg(\s_new, \timerobj, 6000+ix, 0, 301, \ibs, 50, \aobs, 100+ix, \kobs, 100+ix, \st, st, \end, end);
	}, "/timer");

	OSCdef( \eventnorm, {
		arg msg;
		var dialnum = msg[1].asInteger;
		var eventnum = msg[2].asInteger;
		var eventclr = msg[3].asString;
		var val = msg[4].asFloat;
	}, "/eventnorm");

	OSCdef( \eventon, {
		arg msg;
		var dialnum = msg[1].asInteger;
		var eventnum = msg[2].asInteger;
		var eventclr = msg[3].asSymbol;
		~eventbyclr[eventclr].value(1);
	}, "/eventon");

	OSCdef( \eventoff, {
		arg msg;
		var dialnum = msg[1].asInteger;
		var eventnum = msg[2].asInteger;
		var eventclr = msg[3].asSymbol;
		~eventbyclr[eventclr].value(0);
	}, "/eventoff");


	0.8.wait;
	//SYNTHS
	s.sendMsg(\s_new, \phasorclock, 5000, 0, 900, \abus, 50, \kbus, 0);

	//INPUTS
	s.sendMsg(\s_new, \playsamp_m, 10000, 0, 901, \obs, 100, \buf, 99, \amp, 1.5); //sax samp; out to abus 100
	s.sendMsg(\s_new, \micin, 20000, 0, 901, \obs, 200, \inch, 0); //mic in; out to abus 200

	//PROCESSED INPUTS
	////////Tape Delayed Version
	s.sendMsg(\s_new, \tapedelay, 15000, 0, 903, \ibs, 100, \obs, 300, \obs2, 0, \gate, 0, \difffreq, 0.07, \difflo, 0.1, \diffhi, 0.9, \delfreq, 0.05, \dello, 0.05, \delhi, 1.5, \fbfreq, 0.033, \fblo, 0.33, \fbhi, 0.77, \atk, 0.02, \rel, 0.15); //out 300


	////////Sample Play Synths
	s.sendMsg(\s_new, \playsamp_s, 10001, 0, 902, \obs, 110, \buf, 0, \amp, 1.0); //icecream truck
	s.sendMsg(\s_new, \playsamp_s, 10002, 0, 902, \obs, 120, \buf, 1, \amp, 1.0); //blackbird
	s.sendMsg(\s_new, \playsamp_s, 10003, 0, 902, \obs, 130, \buf, 2, \amp, 1.0); //tambura
	s.sendMsg(\s_new, \playsamp_s, 10004, 0, 902, \obs, 140, \buf, 3, \amp, 1.0); //unacorda
	s.sendMsg(\s_new, \playsamp_s, 10005, 0, 902, \obs, 150, \buf, 4, \amp, 1.0); //mirdangamRoll1

	~eventbyclr = ();
	~eventbyclr.put(\TranquilBlue, {|msg| msg.postln});
	~eventbyclr.put(\orange, {|msg| msg.postln});
	~eventbyclr.put(\red, {|msg| msg.postln});
	~eventbyclr.put(\green, {|msg| msg.postln});
	~eventbyclr.put(\blue, {|msg| msg.postln});
	~eventbyclr.put("black", {|msg| msg.postln});
	~eventbyclr.put("white", {|msg| msg.postln});
	~eventbyclr.put("violetred", {|msg| msg.postln});
	~eventbyclr.put("springgreen", {|msg| msg.postln});
	~eventbyclr.put("turquoiseblue", {|msg| msg.postln});
	~eventbyclr.put("seagreen", {|msg| msg.postln});
	~eventbyclr.put(\mint, {|msg| s.sendMsg(\n_set, 15000, \gate, msg) } );
	~eventbyclr.put("yellow", {|msg| msg.postln});
	~eventbyclr.put("goldenrod", {|msg| msg.postln});
	~eventbyclr.put("darkorange", {|msg| msg.postln});
	~eventbyclr.put("chocolate", {|msg| msg.postln});
	~eventbyclr.put("slateblue", {|msg| msg.postln});
	~eventbyclr.put("indigo", {|msg| msg.postln});
	~eventbyclr.put("purple", {|msg| msg.postln});
	~eventbyclr.put("magenta", {|msg| msg.postln});
	~eventbyclr.put("plum", {|msg| msg.postln});
	~eventbyclr.put("maroon", {|msg| msg.postln});
	~eventbyclr.put("purple", {|msg| msg.postln});
	~eventbyclr.put("pink", {|msg| msg.postln});
	~eventbyclr.put("royalblue", {|msg| msg.postln});
	~eventbyclr.put("dodgerblue", {|msg| msg.postln});
	~eventbyclr.put("grey", {|msg| msg.postln});
	~eventbyclr.put("pine", {|msg| msg.postln});
	~eventbyclr.put("papaya", {|msg| msg.postln});
	~eventbyclr.put("beet", {|msg| msg.postln});
	~eventbyclr.put("slate", {|msg| msg.postln});
	~eventbyclr.put("peacock", {|msg| msg.postln});
	~eventbyclr.put("fig", {|msg| msg.postln});
	~eventbyclr.put("sunshine", {|msg| msg.postln});
	~eventbyclr.put("limegreen", {|msg| msg.postln});


}/*end fork*/ }/*end s.waitForBoot*/ );


s.meter

//osc messages
n = NetAddr("127.0.0.1", 12321);
//Make a dial
n.sendMsg(\mkdial, 0, 0, 0.0, 1.0, "sunshine", 2); //idx, clknum, radiusnorm1, radiusnorm2, clr, wt
//Make a timer
n.sendMsg(\mktimetrig, 0, 0, 0.667, 2.0, 5.0, "mint", 4); //idx, clknum, radiusnorm, stclock , endclock, clr, wt

n.sendMsg(\mktimetrig, 1, 0, 0.2, 7.5, 8.0, "mint", 9); //idx, clknum, radiusnorm, stclock , endclock, clr, wt
n.sendMsg(\mktimetrig, 2, 0, 0.2, 9.8, 10.3, "mint", 9); //idx, clknum, radiusnorm, stclock , endclock, clr, wt
n.sendMsg(\mktimetrig, 3, 0, 0.2, 8.5, 8.8, "mint", 9); //idx, clknum, radiusnorm, stclock , endclock, clr, wt
n.sendMsg(\rmvtimetrig, 1);


//tapedelay
//120 blackbird
//150 mirdungam
s.sendMsg(\s_new, \tapedelay, 15000, 0, 903, \ibs, 100, \obs, 0, \rawobs, 99); //set in amp in dbs
s.sendMsg(\n_set, 15000, \lfofb, 0.03, \fblo, 0.5, \fbhi, 0.77);
s.sendMsg(\n_set, 15000, \obs, 200);
s.sendMsg(\n_free, 15000);
//lpc
s.sendMsg(\s_new, \lpc, 16000, 0, 904, \caribs, 200, \carobs, 43, \obs, 0, \modibs, 120, \modobs, 40);
s.sendMsg(\n_set, 16000, \carobs, 43, \caramp, -9, \caribs, 200);
s.sendMsg(\n_set, 16000, \modibs, 140, \modamp, 0);
s.sendMsg(\n_set, 16000, \obs, 0, \amp, 0);
s.sendMsg(\n_free, 16000);


/*
add lpcs
////get some new samples
When making a new dial, start a new phasor clock and track the node number
Speed up processing side  start speed, end speed, iterations

More Samples
tweek greyhole lfo settings
Other Articulations - trill, percussive, see the ocean, with lfos
have fade in/out crescendos for fx tied to dial, make new dial object to represent crescendo


*/

