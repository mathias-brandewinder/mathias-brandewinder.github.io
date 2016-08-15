---
layout: post
title: Infinite Monkeys and their typewriters
tags:
- Entropy
- Borges
- Monkey
- Probability
- Order
---

During a recent Internet excursions, I ended up on the [Infinite Monkey Theorem](http://en.wikipedia.org/wiki/Infinite_monkey_theorem) wiki page. The infinite monkey is a somewhat famous figure in probability; his fame comes from the following question: suppose you gave a monkey a typewriter, what’s the likelihood that, given enough time randomly typing, he would produce some noteworthy literary output, say, the complete works of Shakespeare?  

Somewhat unrelatedly, this made me wonder about the following question: imagine that I had a noteworthy literary output and such a monkey – could I get my computer to distinguish these?  

For the sake of experimentation, let’s say that our “tolerable page” is the following paragraph by Jorge Luis Borges:  

> Everything would be in its blind volumes. Everything: the detailed history of the future, Aeschylus' <i>The Egyptians</i>, the exact number of times that the waters of the Ganges have reflected the flight of a falcon, the secret and true nature of Rome, the encyclopedia Novalis would have constructed, my dreams and half-dreams at dawn on August 14, 1934, the proof of Pierre Fermat's theorem, the unwritten chapters of *Edwin Drood*, those same chapters translated into the language spoken by the Garamantes, the paradoxes Berkeley invented concerning Time but didn't publish, Urizen's books of iron, the premature epiphanies of Stephen Dedalus, which would be meaningless before a cycle of a thousand years, the Gnostic Gospel of Basilides, the song the sirens sang, the complete catalog of the Library, the proof of the inaccuracy of that catalog. Everything: but for every sensible line or accurate fact there would be millions of meaningless cacophonies, verbal farragoes, and babblings. Everything: but all the generations of mankind could pass before the dizzying shelves—shelves that obliterate the day and on which chaos lies—ever reward them with a tolerable page. 

Assuming my imaginary typewriter-pounding monkey is typing each letter with equal likelihood, my first thought was that by comparison, a text written in English would have more structure and predictability – and we could use [Entropy](http://en.wikipedia.org/wiki/Information_theory#Entropy) to measure that difference in structure.  

<!--more-->

Entropy is the expected information of a message; the general idea behind it is that a signal where every outcome is equally likely is unpredictable, and has a high entropy, whereas a message where certain outcomes are more frequent than others has more structure and lower entropy.  

The formula for Entropy, lifted from [Wikipedia](http://en.wikipedia.org/wiki/Information_theory#Entropy), is given below; it corresponds to the average quantity of information of a message X, where X can take different values x:  

![ H(X) = \mathbb{E}_{X} [I(x)] = -\sum_{x \in \mathbb{X}} p(x) \log p(x).]({{ site.url }}/assets/2012-05-20-efdf8c905c0f9dfd78002df6f20edb5d.png)  

For instance, a series of coin tosses with the proverbial fair coin would produce about as many heads and tails, and the entropy would come out as `–0.5 x log2(0.5) – 0.5 x log2(0.5) = 1.0`, whereas a totally unfair coin producing only heads would have an entropy of `–1.0 x log2(1.0) – 0.0 = 0.0`, a perfectly predictable signal.  

How could I apply this to my problem?  First, we need a mechanical monkey. Given a sample text (our benchmark), we’ll extract its alphabet (all characters used), and create a virtual typewriter where each key corresponds to one of these characters. The monkey will then produce monkey literature, by producing a string as long as the original text, “typing” on the virtual keyboard randomly:

``` fsharp
let monkey (text: string) =
   let rng = new System.Random()
   let alphabet = Seq.distinct text |> Seq.toArray
   let alphabetLength = Array.length alphabet
   let textLength = text.Length
   [| for i in 1 .. textLength -> 
      alphabet.[rng.Next(0, alphabetLength)] |]
``` 

We store the Borges paragraph as:

``` fsharp
let borges = "Everything would be in its blind volumes. (etc...)
``` 

… and we can now run the Monkey on the Borges paragraph, 

``` fsharp
> new string(monkey borges);;
``` 

which produces a wonderful output (results may vary – you could, after all, get a paragraph of great literary value):

> ovfDG4,xUfETo4Sv1dbxkknthzB19Dgkphz3Tsa1L——w—w iEx-Nra mDs--k3Deoi—hFifskGGBBStU11-iiA3iU'S R9DnhzLForbkhbF:PbAUwP—ir-U4sF u w-tPf4LLuRGsDEP-ssTvvLk3NyaE f:krRUR-Gbx'zShb3wNteEfGwnuFbtsuS9Fw9lgthE1vL,tE4:Uk3UnfS FfxDbcLdpihBT,e'LvuaN4royz ,Aepbu'f1AlRgeRUSBDD.PwzhnA'y.s9:d,F'T3xvEbvNmy.vDtmwyPNotan3Esli' BTFbmywP.fgw9ytAouLAbAP':txFvGvBti Fg,4uEu.grk-rN,tEnvBs3uUo,:39altpBud3'-Aetp,T.chccE1yuDeUT,Pp,R994tnmidffcFonPbkSuw :pvde .grUUTfF1Flb4s cw'apkt GDdwadn-Phn4h.TGoPsyc'pcBEBb,kasl—aepdv,ctA TxrhRUgPAv-ro3s:aD z-FahLcvS3k':emSoz9NTNRDuus3PSpe-Upc9nSnhBovRfoEBDtANiGwvLikp4w—nPDAfknr—p'-:GnPEsULDrm'ub,3EyTmRoDkG9cERvcyxzPmPbD Fuit:lwtsmeUEieiPdnoFUlP'uSscy—Nob'st1:dA.RoLGyakGpfnT.zLb'hsBTo.mRRxNerBD9.wvFzg,,UAc,NSx.9ilLGFmkp—:FnpcpdP—-ScGSkmN9BUL1—uuUpBhpDnwS9NddLSiBLzawcbywiG—-E1DBlx—aN.D9u-ggrs3S4y4eFemo3Ba g'zeF:EsS-gTy-LFiUn3DvSzL3eww4NPLxT13isGb:—vBnLhy'yk1Rsip—res9t vmxftwvEcc::ezvPPziNGPylw:tPrluTl3E,T,vDcydn SyNSooaxaT llwNtwzwoDtoUcwlBdi',UrldaDFeFLk 3goos4unyzmFD9.vSTuuv4.wzbN.ynakoetb—ecTksm—-f,N:PtoNTne3EdErBrzfATPRreBv1:Rb.cfkELlengNkr'L1cA—lfAgU-vs9&#160; Lic-m,kheU9kldUzTAriAg:bBUb'n—x'FL Adsn,kmar'p BE9akNr194gP,hdLrlgvbymp dplh9sPlNf'.'9

Does the entropy of these 2 strings differ? Let’s check.

``` fsharp
let I p =
   match p with
   | 0.0 -> 0.0
   | _ -> - System.Math.Log(p, 2.0)

let freq text letter =
   let count =
      Seq.fold (fun (total, count) l -> 
         if l = letter
         then (total + 1.0, count + 1.0)
         else (total + 1.0, count)) (0.0, 0.0) text
   (letter, snd count / fst count)

let H text =
   let alphabet = Seq.distinct text
   Seq.map (fun l -> snd (freq text l)) alphabet
   |> Seq.sumBy (fun p -> p * I(p))
``` 

`I` computes the [self-information](http://en.wikipedia.org/wiki/Self-information) of a message of probability p, freq computes the frequency of a particular character within a string, and H, the entropy, proceeds by first extracting all the distinct characters present in the text into an “alphabet”, and then maps each character of the alphabet to its frequency and computes the expected self-information.

We have now all we need – let’s see the results:

``` fsharp
> H borges;;
val it : float = 4.42083025
> H monkeyLit;;
val it : float = 5.565782825
``` 

Monkey lit has a higher entropy / disorder than Jorge Luis Borges’ output. This is reassuring.

How good of a test is this, though? In the end, what we measured with Entropy is that some letters were more likely to come up than others, which we would expect from a text written in English, where the [letter “e” has a 12% probability to show up](http://en.wikipedia.org/wiki/Letter_frequency#Relative_frequencies_of_letters_in_the_English_language). However, if we gave our Monkey a [Dvorak keyboard](http://www.dvorak-keyboard.com/), he may fool our test; we could also create an uber Mechanical Monkey which generates a string based on the original text frequency:

``` fsharp
let uberMonkey (text: string) =
   let rng = new System.Random()
   let alphabet = Seq.distinct text |> Seq.toArray
   let textLength = text.Length
   let freq = Array.map (fun l -> freq text l) alphabet
   let rec index i p cumul =
      let cumul = cumul + snd freq.[i]
      if cumul >= p then i else index (i+1) p cumul
   [| for i in 1 .. textLength -> 
      let p = rng.NextDouble()
      alphabet.[index 0 p 0.0] |]
``` 

This somewhat ugly snippet computes the frequency of every letter in the original text, and returns random chars based on the frequency. The ugly part is the index function; given a probability p, it returns the index of the first char in the frequency array such that the cumulative probability of all chars up to that index is greater than p, which will return each index based on its frequency.

Running the uberMonkey produces another milestone of worldwide literature:

> lk&#160; aeew omauG dga rlhhfatywrrg&#160;&#160; earErhsgeotnrtd utntcnd&#160; o,&#160; ntnnrcl gltnhtlu eAal yeh uro&#160; it-lnfELiect eaurefe Busfehe h f1efeh hs eo.dhoc , rbnenotsno, e et tdiobronnaeonioumnroe&#160; escr l hlvrds anoslpstr'thstrao lttamxeda iotoaeAB ai sfoF,hfiemnbe ieoobGrta dogdirisee nt.eba&#160;&#160; t oisfgcrn&#160; eehhfrE' oufepas Eroshhteep snodlahe sau&#160; eoalymeonrt.ss.ehstwtee,ttudtmr ehtlni,rnre&#160; ae h&#160; e chp c crng Rdd&#160; eucaetee gire dieeyGhr a4ELd&#160; sr era tndtfe rsecltfu&#160; t1tefetiweoroetasfl bnecdt'eetoruvmtl ii fi4fprBla Fpemaatnlerhig&#160; oteriwnEaerebepnrsorotcigeotioR g&#160; bolrnoexsbtuorsr si,nibbtcrlte uh ts ot&#160; trotnee&#160;&#160; se rgfTf&#160; ibdr ne,UlA sirrr a,ersus simf bset&#160; guecr s tir9tb e ntcenkwseerysorlddaaRcwer ton redts— nel ye oi leh v t go,amsPn 'e&#160; areilynmfe ae&#160; evr&#160; lino t, s&#160;&#160; a,a,ytinms&#160;&#160; elt i :wpa s s hAEgocetduasmrlfaar&#160; de cl,aeird fefsef E&#160; s se hplcihf f&#160; cerrn rnfvmrdpo ettvtu oeutnrk —toc anrhhne&#160; apxbmaio hh&#160; edhst, mfeveulekd. vrtltoietndnuphhgp rt1ocfplrthom b gmeerfmh tdnennletlie hshcy,,bff,na nfitgdtbyowsaooomg , hmtdfidha l aira chh olnnehehe acBeee&#160; n&#160; nrfhGh dn toclraimeovbca atesfgc:rt&#160; eevuwdeoienpttdifgotebeegc ehms ontdec e,ttmae llwcdoh

… and, as expected, if we run our Entropy function on uberMonkeyLit, we get

``` fsharp
> H uberMonkeyLit;;
val it : float = 4.385303632
``` 

This is pretty much what we got with the Borges original. The uberMonkey produced a paragraph just as organized as Borges, or so it seems.

Obviously, the raw Entropy calculation is not cutting it here. So what are we missing? The problem is that we are simply looking at the frequency of characters, which measures a certain form of order / predictability; however, there is “more” order than that in English. If I were to tell you that the 2 first characters of a text are “Th”, chances are, you would bet on “e” for the third position – because some sequences are much more likely than others, and “The” much more probable than “Thw”. The “raw” Entropy would consider the two following sequences “ABAABABB” and “ABABABAB” equally ordered (each contains 4 As and 4 Bs), whereas a human eye would consider that the second one, with its neat succession of A and Bs, may follow a pattern, where knowing the previous observations of the sequence conveys some information about what’s likely to show up next.

We’ll leave it at that for today, with an encouraging thought for those of you who may now worry that world literature could be threaten by offshore monkey typists. According to [Wikipedia](http://en.wikipedia.org/wiki/Infinite_monkey_theorem#Real_monkeys) again, 

> In 2003, lecturers and students from the University of Plymouth MediaLab Arts course used a £2,000 grant from the Arts Council to study the literary output of real monkeys. They left a computer keyboard in the enclosure of six Celebes Crested Macaques in Paignton Zoo in Devon in England for a month, with a radio link to broadcast the results on a website.  

> Not only did the monkeys produce nothing but five pages consisting largely of the letter [S](http://en.wikipedia.org/wiki/S), the lead male began by bashing the keyboard with a stone, and the monkeys continued by urinating and defecating on it. Phillips said that the artist-funded project was primarily performance art, and they had learned "an awful lot" from it.

£2,000 may seem a bit steep to watch monkeys defecating on typewriters; on the other hand, it seems that human writers can sleep quietly, without worrying about their jobs.
