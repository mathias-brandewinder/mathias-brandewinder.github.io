---
layout: post
title: Learning from mistakes&#58; Winnow algorithm in F#
tags:
- F#
- Machine-Learning
- Classification
- Algorithms
- Online-Learning
- N-grams
- Winnow
---

During some recent meanderings through the confines of the internet, I ended up discovering the [Winnow Algorithm](http://www.cc.gatech.edu/~ninamf/ML11/lect0906.pdf). The simplicity of the approach intrigued me, so I thought it would be interesting to try and implement it in F# and see how well it worked.

<!--more-->

The purpose of the algorithm is to train a binary classifier, based on binary features. In other words, the goal is to predict one of two states, using a collection of features which are all binary. The prediction model assigns weights to each feature; to predict the state of an observation, it checks all the features that are “active” (true), and sums up the weights assigned to these features. If the total is above a certain threshold, the result is true, otherwise it’s false. Dead simple – and so is the corresponding F# code:

``` fsharp
type Observation = bool []
type Label = bool
type Example = Label * Observation
type Weights = float []
 
let predict (theta:float) (w:Weights) (obs:Observation) =
    (obs,w) ||> Seq.zip
    |> Seq.filter fst
    |> Seq.sumBy snd
    |> ((<) theta)
```

We create some type aliases for convenience, and write a predict function which takes in theta (the threshold), weights and and observation; we zip together the features and the weights, exclude the pairs where the feature is not active, sum the weights, check whether the threshold is lower that the total, and we are done.

In a nutshell, the learning process feeds examples (observations with known label), and progressively updates the weights when the model makes mistakes. If the current model predicts the output correctly, don’t change anything. If it predicts true but should predict false, it is over-shooting, so weights that were used in the prediction (i.e. the weights attached to active features) are reduced. Conversely, if the prediction is false but the correct result should be true, the active features are not used enough to reach the threshold, so they should be bumped up.

And that’s pretty much it – the algorithm starts with arbitrary initial weights of 1 for every feature, and either doubles or halves them based on the mistakes. Again, the F# implementation is completely straightforward. The weights update can be written as follows:

``` fsharp
let update (theta:float) (alpha:float) (w:Weights) (ex:Example) =
    let real,obs = ex
    match (real,predict theta w obs) with
    | (true,false) -> w |> Array.mapi (fun i x -> if obs.[i] then alpha * x else x)
    | (false,true) -> w |> Array.mapi (fun i x -> if obs.[i] then x / alpha else x)
    | _ -> w
```

Let’s check that the update mechanism works:

```
> update 0.5 2. [|1.;1.;|] (false,[|false;true;|]);;
val it : float [] = [|1.0; 0.5|]
```

The threshold is 0.5, the adjustment multiplier is 2, and each feature is currently weighted at 1. The state of our example is `[| false; true; |]`, so only the second feature is active, which means that the predicted value will be 1. (the weight of that feature). This is above the threshold 0.5, so the predicted value is true. However, because the correct value attached to that example is false, our prediction is incorrect, and the weight of the second feature is reduced, while the first one, which was not active, remains unchanged.

Let’s wrap this up in a convenience function which will learn from a sequence of examples, and give us directly a function that will classify observations:

``` fsharp
let learn (theta:float) (alpha:float) (fs:int) (xs:Example seq) =
    let updater = update theta alpha
    let w0 = [| for f in 1 .. fs -> 1. |]   
    let w = Seq.fold (fun w x -> updater w x) w0 xs
    fun (obs:Observation) -> predict theta w obs
```

We pass in the number of features, fs, to initialize the weights at the correct size, and use a fold to update the weights for each example in the sequence. Finally, we create and return a function that, given an observation, will predict the label, based on the weights we just learnt.

And that’s it – in 20 lines of code, we are done, the Winnow is implemented.

But… does it work? An example doesn’t prove anything, of course, but I was curious, and cooked up the following idea. Let’s use the Winnow to predict if the next character in a piece of text is going to be a letter, or something else (space, punctuation…), based on the previous characters. In other words, let’s try to predict if we reached the end of a word.

To simplify the coding part a bit, I will ignore case, and convert every character to upper case. Obviously, whether a character is upper or lower case is relevant to where we are in a word, but my goal here is just to satisfy my curiosity, so I will ignore that and be lazy. The letters A to Z correspond to char 65 to 90 (that’s an alphabet of 26 characters), and I also want to catch everything that isn’t a letter. One way we can then encode a character so that it fits our requirement of binary features is the following: create an array of 27 slots, and mark with true the slot corresponding to the letter, reserving the last slot for the case “not a letter”.

I will readily admit it, the following code is a bit ugly (there is probably a cleaner way to do that), but gets the work done:

``` fsharp
let letter (c:char) = int c >= 65 && int c <= 90
 
let encode (c:char) =
    let vec = Array.create (90-65+2) false   
    let x = int c
    if (x >= 65 && x <= 90)
    then vec.[x-65] <- true
    else vec.[90-65+1] <- true
vec
 
let prepare (cs:char[]) =
    cs |> Seq.map encode |> Array.concat
```

letter simply recognizes if a char is an uppercase letter, encode creates a vector representing a character, and prepare takes in an array of chars, and returns an array which puts side-by-side each of the encoded characters. As an example,

```
> encode 'B';;
val it : bool [] =
[|false; true; false; false; false; false; false; false; false; false; false;
false; false; false; false; false; false; false; false; false; false;
false; false; false; false; false; false|]
```

This returns an array of 27 booleans – all of them false, except the second position, which corresponds to B’s position in the alphabet.

We will try to predict the next character based not only on the previous one, but rather on the preceding sequence, the [N-gram](http://en.wikipedia.org/wiki/N-gram). Let’s write a quick and dirty function to transform a string into N-grams, and whether the character that immediately follows is the end of a word, or any letter:

``` fsharp
let ngrams n (text:string) =
text.ToUpperInvariant()
|> Seq.windowed (n+1)
|> Seq.map (fun x -> x.[n],x.[0..(n-1)])
|> Seq.map (fun (c,cs) -> letter c |> not, prepare cs)
```

And we are ready to go. What I am really interested in here is not that much how good or bad the classifier is, but whether it actually improves as it gets feds more data. To observe that, let’s do the following: we’ll use a body of text for training, and another one for validation; we will train the classifier on a larger and larger portion of the training text, and measure the quality of the various models by applying it to the validation text.

We will train the model on a paragraph by Borges, and validate on some Cicero, both lifted from the [Total Library section in the Infinite Monkey wikipedia page](http://en.wikipedia.org/wiki/Infinite_monkey_theorem#Origins_and_.22The_Total_Library.22).

Training:

> Everything would be in its blind volumes. Everything: the detailed history of the future, Aeschylus' The Egyptians, the exact number of times that the waters of the Ganges have reflected the flight of a falcon, the secret and true nature of Rome, the encyclopedia Novalis would have constructed, my dreams and half-dreams at dawn on August 14, 1934, the proof of Pierre Fermat's theorem, the unwritten chapters of Edwin Drood, those same chapters translated into the language spoken by the Garamantes, the paradoxes Berkeley invented concerning Time but didn't publish, Urizen's books of iron, the premature epiphanies ofStephen Dedalus, which would be meaningless before a cycle of a thousand years, the Gnostic Gospel of Basilides, the song the sirens sang, the complete catalog of the Library, the proof of the inaccuracy of that catalog. Everything: but for every sensible line or accurate fact there would be millions of meaningless cacophonies, verbal farragoes, and babblings. Everything: but all the generations of mankind could pass before the dizzying shelves—shelves that obliterate the day and on which chaos lies—ever reward them with a tolerable page.

Validation:

> He who believes this may as well believe that if a great quantity of the one-and-twenty letters, composed either of gold or any other matter, were thrown upon the ground, they would fall into such order as legibly to form the Annals of Ennius. I doubt whether fortune could make a single verse of them.

Here is how one might go about coding that experiment:

``` fsharp
let training = ngrams 3 borges
let validation = ngrams 3 cicero
 
let len = Seq.length training
    for l in 25 .. 25 .. (len - 1) do
    let sample = training |> Seq.take l
    let model = learn 0.5 2. (3*(92-65)) sample
    validation
    |> Seq.averageBy (fun (l,o) ->
    if l = model o then 1. else 0.)
    |> printfn "Sample: %i, correct: %.4f" l
```

Running that code will produce some rather unexciting output:

```
Sample: 25, correct: 0.2168 
Sample: 50, correct: 0.4434 
Sample: 75, correct: 0.5049 
Sample: 100, correct: 0.5955 
Sample: 125, correct: 0.5081 
Sample: 150, correct: 0.6861

// snipped because more of the same

Sample: 1125, correct: 0.7476 
Sample: 1150, correct: 0.6278 
Sample: 1175, correct: 0.6893 
Sample: 1200, correct: 0.7314
```

Visibly, the quality starts pretty low, with around 21% correct predictions for the smallest sample, climbs up as the sample increases, and ends up oscillating in the 65% – 75% range. This isn’t a proof of anything, of course, but it seems to indicate that the model is “learning”, getting better and better at recognizing word endings as it is fed more 3-grams.

And that’s as far as I’ll go on the Winnow. I thought this was an interesting algorithm, if only for its simplicity. It is also suitable for online learning: you don’t need to train your model on a dataset before using it - it can progressively learn on the fly as data is arriving, and the only state you need to maintain is the latest set of weights. The biggest limitation is that it is a linear classifier, which assumes that the data can be cleanly separated along a plane.

In any case, I definitely had fun playing with this – I hope you did, too!
