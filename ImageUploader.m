Begin["SOUploader`"];

Global`palette = PaletteNotebook@DynamicModule[{},
   
   Column[{
     Button["Upload to SE",
      With[{img = rasterizeSelection1[]}, 
       If[img === $Failed, Beep[], uploadWithPreview[img]]],
      Appearance -> "Palette"],
     
     If[$OperatingSystem === "Windows",
      
      Button["Upload to SE (pp)",
       With[{img = rasterizeSelection2[]}, 
        If[img === $Failed, Beep[], uploadWithPreview[img]]],
       Appearance -> "Palette"],
      
      Unevaluated@Sequence[]
      ]
     }],
   
   (* init start *)
   Initialization :>
    (
     
     stackImage::httperr = "Server returned respose code: `1`";
     stackImage::err = "Server returner error: `1`";
     
     stackImage[g_] :=
      Module[
       {getVal, url, client, method, data, partSource, part, entity, 
        code, response, error, result},
       
       getVal[res_, key_String] :=
        With[{k = "var " <> key <> " = "},
         StringTrim[
          
          First@StringCases[
            First@Select[res, StringMatchQ[#, k ~~ ___] &], 
            k ~~ v___ ~~ ";" :> v],
          "'"]
         ];
       
       data = ExportString[g, "PNG"];
       
       JLink`JavaBlock[
        url = "http://stackoverflow.com/upload/image";
        client = JLink`JavaNew["org.apache.commons.httpclient.HttpClient"];
        method = JLink`JavaNew["org.apache.commons.httpclient.methods.PostMethod", url];
        partSource = JLink`JavaNew[
						"org.apache.commons.httpclient.methods.multipart.ByteArrayPartSource", "mmagraphics.png", 
          				JLink`MakeJavaObject[data]@toCharArray[]];
        part = JLink`JavaNew["org.apache.commons.httpclient.methods.multipart.FilePart", "name", partSource];
        part@setContentType["image/png"];
        entity = JLink`JavaNew[
         			"org.apache.commons.httpclient.methods.multipart.MultipartRequestEntity", 
         			{part}, method@getParams[]];
        method@setRequestEntity[entity];
        code = client@executeMethod[method];
        response = method@getResponseBodyAsString[];
       ];
       
       If[code =!= 200, Message[stackImage::httperr, code]; Return[$Failed]];
       response = StringTrim /@ StringSplit[response, "\n"];
       
       error = getVal[response, "error"];
       result = getVal[response, "result"];
       If[StringMatchQ[result, "http*"],
        result,
        Message[stackImage::err, error]; $Failed]
       ];
     
     stackMarkdown[g_] := 
      "![Mathematica graphics](" <> stackImage[g] <> ")";
     
     stackCopyMarkdown[g_] := 
      Module[{nb, markdown},
       markdown = Check[stackMarkdown[g], $Failed];
       If[markdown =!= $Failed,
        nb = NotebookCreate[Visible -> False];
        NotebookWrite[nb, Cell[markdown, "Text"]];
        SelectionMove[nb, All, Notebook];
        FrontEndTokenExecute[nb, "Copy"];
        NotebookClose[nb];
       ]
      ];
     
     (* returns available vertical screen space, 
     taking into account screen elements like the taskbar and menu *)
     
     screenHeight[] := -Subtract @@ 
        Part[ScreenRectangle /. Options[$FrontEnd, ScreenRectangle], 2];
     
     uploadWithPreview[img_Image] :=
      CreateDialog[
       Column[{
         Style["Upload image to StackExchange network?", Bold],
         Pane[
          Image[img, Magnification -> 1], {Automatic, 
           Min[screenHeight[] - 140, 1 + ImageDimensions[img][[2]]]},
          Scrollbars -> Automatic, AppearanceElements -> {}, 
          ImageMargins -> 0
          ],
         Item[ChoiceButtons[{"Upload and copy MarkDown"}, {stackCopyMarkdown[img]; DialogReturn[]}], Alignment -> Right]
         }],
       WindowTitle -> "Upload image to StackExchange?"
       ];
     
     (* Multiplatform, fixed-width version.  
     The default max width is 650 to fit StackExchange *)
     rasterizeSelection1[maxWidth_: 650] := 
      Module[{target, selection, image},
       selection = NotebookRead[SelectedNotebook[]];
       If[MemberQ[Hold[{}, $Failed, NotebookRead[$Failed]], selection],
        
        $Failed, (* there was nothing selected *)
        
        target = CreateDocument[{}, WindowSelected -> False, Visible -> False, WindowSize -> maxWidth];
        NotebookWrite[target, selection];
        image = Rasterize[target, "Image"];
        NotebookClose[target];
        image
        ]
       ];
     
     (* Windows-only pixel perfect version *)
     rasterizeSelection2[] :=
      If[
       MemberQ[Hold[{}, $Failed, NotebookRead[$Failed]], NotebookRead[SelectedNotebook[]]],
       
       $Failed, (* there was nothing selected *)
       
       Module[{tag},
        FrontEndExecute[FrontEndToken[FrontEnd`SelectedNotebook[], "CopySpecial", "MGF"]];
        Catch[
         NotebookGet@ClipboardNotebook[] /. 
          r_RasterBox :> 
           Block[{}, 
            Throw[Image[First[r], "Byte", ColorSpace -> "RGB"], tag] /;
              True];
         $Failed,
         tag
         ]
        ]
       ];
     ) 
   (* init end *)
   ]

End[];