( s.options.numAudioBusChannels=300; s.waitForBoot{ fork{
	//GROUPS
	s.sendMsg(\g_new, 900, 1, 1);
	9.do{|ix| s.sendMsg(\g_new, 901+ix, 3 /*add after*/, 900+ix)};
	//LOAD SAMPLES
	~path = "/Users/jyang/GitHub/liveprocessing/samples/";
	//sax sample at buffer #300
	s.sendMsg(\b_allocRead, 300, ~path ++ "saxsample.aif");
	//SYNTH DEFS

	/*
	SynthDef(\template, {
	arg ibs,obs=0,atk=0.02,rel=0.1,crv= 0,gate=1;
	var src, sig, env, amp;
	amp = \amp.kr(0.85,0.01);
	env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
	src = In.ar(ibs);
	sig = FX(source);
	Out.ar(obs, sig*amp*env);
	}).add;
	*/

	SynthDef(\playsamp_m, {
		arg obs=0,atk=0.02,rel=0.1,crv= 0,gate=1,
		buf;
		var sig, env, amp;
		amp = \amp.kr(0.85,0.01);
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		sig = PlayBuf.ar(1, buf, loop:1);
		Out.ar(obs, sig*amp*env);
	}).add;


	//Duster
	SynthDef(\duster, {
		arg ibs,obs=0,atk=0.02,rel=0.1,crv= 0,gate=1,
		dens=2, gatk=0.01, grel=0.1, gcrv= -4;
		var src, sig, env, amp, trig, trigenv, inamp, rpos, pansig;
		inamp = \inamp.kr(1.0, 0.01);
		trig = Dust.kr(dens);
		trigenv = EnvGen.ar(Env.perc(gatk, grel, curve:gcrv), trig);
		rpos = TRand.kr(-1.0, 1.0, trig);
		amp = \amp.kr(0.85,0.01);
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		src = In.ar(ibs);
		sig = src*trigenv;
		pansig = Pan2.ar(sig, rpos);
		Out.ar(obs, pansig*amp);
	}).add;

	//Pitched Resonant Filters
	SynthDef(\pitchedfilters, {
		arg ibs,obs=0,atk=0.02,rel=0.1,crv= 0,gate=1,
		decay1=0.08, decay2=0.08, fq1=130, fq2=298, fq3=572, fq4=894, mix=0.98, pslo1= -12, pshi1=12, pslo2= -12, pshi2 = 12;
		var src1, src2, sig1, sig2, env, amp, freq1, hasfreq1, freq2, hasfreq2, famp, sig3, sig4;
		amp = \amp.kr(5,0.01);
		famp = \famp.kr(13.0, 0.01);
		env = EnvGen.ar( Env.asr(atk, 1, rel, crv), gate );
		src1 = In.ar(ibs);
		src2 = In.ar(ibs+1);
		# freq1, hasfreq1 = Tartini.kr(src1);
		# freq2, hasfreq2 = Tartini.kr(src1);
		sig1 = ComplexRes.ar(src1, (freq1.cpsmidi+SinOsc.kr(fq1).range(pslo1, pshi1)).midicps, decay1)*famp;
		sig2 = ComplexRes.ar(src2, (freq2.cpsmidi+SinOsc.kr(fq2).range(pslo2, pshi2)).midicps, decay2)*famp;
		sig3 = ComplexRes.ar(src1, (freq1.cpsmidi+SinOsc.kr(fq3).range(pslo1, pshi1)).midicps, decay1)*famp;
		sig4 = ComplexRes.ar(src2, (freq2.cpsmidi+SinOsc.kr(fq4).range(pslo2, pshi2)).midicps, decay2)*famp;
		sig1 = Mix.ar([sig1*mix, src1*(1.0-mix), sig3*mix]);
		sig2 = Mix.ar([sig2*mix, src2*(1.0-mix), sig4*mix]);
		Out.ar(0, [sig1, sig2]*amp);
	}).add;


	0.5.wait;

	//Start Sax Loop Playing to Private Audio Bus #100, node, 3000, group 903
	s.sendMsg(\s_new, \playsamp_m, 3000, 0, 903, \buf, 300, \obs, 100, \amp, 1.5);

}})

//Start Duster node-3010, group 904, in from abus 100
s.sendMsg(\s_new, \duster, 3010, 0, 904, \ibs, 100, \obs, 0, \dens, 3);
s.sendMsg(\n_set, 3010, \gatk, 0.01, \grel, 0.08, \gcrv, -3, \dens, 7, \amp, 3, \obs, 150);
s.sendMsg(\n_set, 3010, \gatk, 0.01, \grel, 0.1, \gcrv, -3, \dens, 9, \amp, 3, \obs, 150);
s.sendMsg(\n_free, 3010);
s.meter;

//PUT DENSITY ON A RANDOM TRIGGER
//PUT PSHI/LO ON RANDOM TRIGGERS
//random rate/pitch triggers based on messiaen modes - add more filters


s.sendMsg(\s_new, \pitchedfilters, 3020, 0, 905, \ibs, 150, \obs, 0);
s.sendMsg(\n_set, 3020, \famp, 12, \decay1, 0.08, \decay2, 0.08, \mix, 0.99, \amp, 4, \fq1, 120, \fq2, 480, \fq3, 840, \fq4, 1200, \pslo1, -11, \pshi1,  11, \pslo2, -11, \pshi2, 11);
s.sendMsg(\n_set, 3020, \famp, 12, \decay1, 0.08, \decay2, 0.08, \mix, 0.99, \amp, 4, \fq1, 1200, \fq2, 4080, \fq3, 8040, \fq4, 12000, \pslo1, -4, \pshi1,  4, \pslo2, -4, \pshi2, 4);
s.sendMsg(\n_free, 3020);

add harmonics
add lfo to rate