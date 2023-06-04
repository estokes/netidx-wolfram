(* ::Package:: *)

(* ::Section:: *)
(*Package Header*)


BeginPackage["Netidx`"];


(* ::Text:: *)
(*Declare your public symbols here:*)


Subscribe::usage = "Subscribe[path, callback], calls callback with the value of path whenever it updates";
Unsubscribe::usage = "Unsubscribe[path, id], unsubscribes the callback named by id (returned by subscribe) from the path";


Begin["`Private`"];


(* ::Section:: *)
(*Definitions*)


(* ::Text:: *)
(*Define your public and private symbols here:*)


callbackId = 0;

subscriptions = Association[];

subscriptionHandler[taskObject_, "update", updates_] :=
	Function[l, #[l[[2]]]& /@ subscriptions[l[[1]]]] /@ updates;

subscriptionTask = Internal`CreateAsynchronousTask[
	LibraryFunctionLoad[
		"libnetidx_wolfram", 
		"start_netidx_subscriber",
		{}, 
		Integer
	], 
	{}, 
	netidxHandler
];

doSubscribe = LibraryFunctionLoad[
	"libnetidx_wolfram", 
	"subscribe", 
	{String}, 
	"Void"
];

Subscribe[path_, f_] := Module[{id},
	id = callbackId;
	callbackId = callbackId + 1;
	subscriptions[path][id] = f;
	doSubscribe(path);
	id
]


(* ::Section::Closed:: *)
(*Package Footer*)


End[];
EndPackage[];
