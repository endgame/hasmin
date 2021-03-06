{-# LANGUAGE OverloadedStrings #-}

module Hasmin.Types.StylesheetSpec where

import Data.Text (Text, unpack)

import Hasmin.Parser.Internal
import Hasmin.TestUtils
import Hasmin.Class
import Hasmin.Types.Stylesheet
import Hasmin

combineAdjacentMediaQueriesTests :: Spec
combineAdjacentMediaQueriesTests =
     describe "Combines adjacent @media rules" $
      mapM_ f combineAdjacentMediaQueriesTestsInfo
  where f (t1, t2) = it (unpack t1) $ minifyCSS t1 `parseSatisfies` (== t2)

combineAdjacentMediaQueriesTestsInfo :: [(Text, Text)]
combineAdjacentMediaQueriesTestsInfo =
  [("@media (min-width:24rem){.Fz\\(s2\\)\\@xs{font-size:1.2rem;}}@media (min-width:24rem){.Px\\(s04\\)\\@xs{padding-left:.25rem; padding-right:.25rem;}}",
    "@media (min-width:24rem){.Fz\\(s2\\)\\@xs{font-size:1.2rem}.Px\\(s04\\)\\@xs{padding-left:.25rem;padding-right:.25rem}}")


  {- TODO make Eq instance handle this equality.
   -
  ,("@media all and (min-width:24rem){.Fz\\(s2\\)\\@xs{font-size:1.2rem;}}@media (min-width:24rem){.Px\\(s04\\)\\@xs{padding-left:.25rem; padding-right:.25rem;}}",
    "@media (min-width:24rem){.Fz\\(s2\\)\\@xs{font-size:1.2rem}.Px\\(s04\\)\\@xs{padding-left:.25rem;padding-right:.25rem}}")
  -}
  ]

atRuleTests :: Spec
atRuleTests = do
    describe "at rules parsing and printing" $
      mapM_ (matchSpec atRule) atRuleTestsInfo
    describe "@supports minification" $
      mapM_ (matchSpec (minifyWithTestConfig <$> atRule)) atSupportsTestInfo
    describe "@import minification" $
      mapM_ (matchSpec (minifyWithTestConfig <$> atRule)) atImportTestInfo
    describe "@media minification" $
      mapM_ (matchSpec (minifyWithTestConfig <$> atRule)) atMediaTestInfo

atMediaTestInfo :: [(Text, Text)]
atMediaTestInfo =
  [("@media all {h1{color:red}}",
    "@media {h1{color:red}}")
  ,("@media all and (min-width: 500px){h1 {color: red}}",
    "@media (min-width:500px){h1{color:red}}")
  ,("@media not all{h1{color:red}}",
    "@media not all{h1{color:red}}")
  ,("@media all and (min-width:500px), not all and (min-device-pixel-ratio:0){h1{a:a}}",
    "@media (min-width:500px),not all and (min-device-pixel-ratio:0){h1{a:a}}")
  ,("@media (min-width:500px),all and (min-device-pixel-ratio:0){h1{a:a}}",
    "@media (min-width:500px),(min-device-pixel-ratio:0){h1{a:a}}")
  ,("@media only all{h1{a:a}}",
    "@media only all{h1{a:a}}")
  ]

atImportTestInfo :: [(Text, Text)]
atImportTestInfo =
  [("@import  url(\'landscape.css\');",
      "@import \"landscape.css\";")
  ,("@import url(landscape.css);",
      "@import \"landscape.css\";")
  ,("@import url(landscape.css) all;",
      "@import \"landscape.css\";")
  ,("@import url(landscape.css) screen, all and (min-width:500px);",
      "@import \"landscape.css\" screen,(min-width:500px);")
  ,("@import url(landscape.css) all and (min-width:500px);",
      "@import \"landscape.css\" (min-width:500px);")
  ]

mergeRulesTest :: Spec
mergeRulesTest =
    describe "Rules merging" $
      mapM_ (matchSpecWithDesc ((f . minifyWithTestConfig) <$> rules)) mergeRulesTestsInfo
  where f = mconcat . map toText

mergeRulesTestsInfo :: [(String, Text, Text)]
mergeRulesTestsInfo =
  [("Combine adjacent rules with the same declarations",
      "h1{margin:10px}h2{margin:10px}",
      "h1,h2{margin:10px}")
  ,("Merge rules with identical selectors, and combine margin-bottom into margin",
    ".a{margin:10px}.a{margin-bottom:5px}",
    ".a{margin:10px 10px 5px}")
  ,("Merge rules with identical selectors, and remove overwritten margin-bottom",
    ".a{margin-bottom:10px}.a{margin:5px}",
    ".a{margin:5px}")
  ,("Merge rules with identical declarations, when a same specificity rule is in-between but the declarations don't interfere",
    ".a{border-left-color:red}.b{border-right-color:blue}.c{border-left-color:red}",
    ".a,.c{border-left-color:red}.b{border-right-color:blue}")
  ,("Don't merge rules that share selectors, but not every selector",
    "table,video{margin:0}ol,ul{list-style:none}table{border-collapse:collapse}",
    "table,video{margin:0}ol,ul{list-style:none}table{border-collapse:collapse}")
  ,("Don't combine rules with the same selectors when there is another in-between with the same specificity and a declaration that clashes",
    ".a p{margin:10px 0}.b p{margin:10px auto}.a p{margin-bottom:5px}",
    ".a p{margin:10px 0}.b p{margin:10px auto}.a p{margin-bottom:5px}")
  ,("Merge example from csso/issues/217 properly",
    ".a{float:left}.b{background:red}.c{color:#fff}.d{text-decoration:none}.e{float:left}.d{float:left}",
    ".a,.e,.d{float:left}.b{background:red}.c{color:#fff}.d{text-decoration:none}")
  ,("When merging rules, ignores @keyframes rule inbetween",
    ".a{color:red}@keyframes foo{0%{frame:1}to{frame:2}}.b{color:red}",
    ".a,.b{color:red}@keyframes foo{0%{frame:1}to{frame:2}}")
  ,("When merging rules, ignores @font-face rule inbetween",
    ".a{color:red}@font-face{test:1}.b{color:red}",
    ".a,.b{color:red}@font-face{test:1}")
    {- TODO
  ,("Merge rules with identical selectors, and combine font-weight into font",
    ".a{font:700 65%/1.5 sans-serif}.a{font-weight:400}",
    ".a{font:400 65%/1.5 sans-serif}")
    -}
  {-TODO considering gzip, is implementing this worth it?
  ,("csso 1",
    "a{padding:0;margin:0}b{padding:0}",
    "a,b{padding:0}a{margin:0}")
  ,("csso 2",
    "a{padding:0}b{padding:0;margin:0}",
    "a,b{padding:0}b{margin:0}")
  ,("csso 3",
    "a{padding:0}b{padding:0;margin:0}c{margin:0}",
    "a,b{padding:0}b,c{margin:0}")
  ,("csso 4",
    "a{padding:0}elementWithAnAbsurdlyVeryLongName{padding:0;margin:0}c{margin:0}",
    "a{padding:v}elementWithAnAbsurdlyVeryLongName{padding:0;margin:0}c{margin:0}")
  ,("csso ",
    ".foo{margin:0;padding:2px}.bar{margin:1px;padding:2px}",
    ".bar,.foo{margin:0;padding:2px}.bar{margin:1px}")
  -}
  ]

atSupportsTestInfo :: [(Text, Text)]
atSupportsTestInfo =
  [("@supports not (not (a:a)){s{b:b}}",
      "@supports (a:a){s{b:b}}")
  ]

-- TODO test for
{-
.gallery-loading .gallery-loading-container {
  background: #fff url("//corporate-website-test.s3.amazonaws.com/wp-content/themes/ggs-rcw/img/spinner_white_125px.gif") no-repeat center center;
}
-}
atRuleTestsInfo :: [(Text, Text)]
atRuleTestsInfo =
  [("@charset \"UTF-8\";",
      "@charset \"UTF-8\";")
  ,("@import/**/ 'custom.css' ;",
      "@import 'custom.css';")
  ,("@import  \"common.css\" screen , projection;",
      "@import \"common.css\" screen,projection;")
  ,("@import  url(\'landscape.css\')  screen  and  (orientation: landscape);",
      "@import url(\'landscape.css\') screen and (orientation:landscape);")
  ,("@namespace /**/ prefix url(XML-namespace-URL);",
      "@namespace prefix url(XML-namespace-URL);")
  ,("@namespace  prefix /**/  \"XML-namespace-URL\";",
      "@namespace prefix \"XML-namespace-URL\";")
  ,("@media screen {s{a:a}}",
      "@media screen{s{a:a}}")
  ,("@media screen and (min-width: 768px){s{a:a}}",
      "@media screen and (min-width:768px){s{a:a}}")
  ,("@keyframes p { from { background-position: 40px 0 } to { background-position: 0 0 } }",
      "@keyframes p{from{background-position:40px 0}to{background-position:0 0}}")
  ,("@font-face  /**/ {a:a;}",
      "@font-face{a:a}")
  -- Uncomment once custom properties are supported
  -- ,("@supports (--foo: green) { body { color: green; } }",
     -- "@supports (--foo:green){body{color:green}}")
  ,("@supports ( transform-style: preserve ) or ( -moz-transform-style: preserve ){s{a:a}}",
     "@supports (transform-style:preserve) or (-moz-transform-style:preserve){s{a:a}}")
  ,("@supports ( display : table-cell ) and ( not ( display : list-item ) ){s{a:a}}",
    "@supports (display:table-cell) and (not (display:list-item)){s{a:a}}")
  ,("@supports not ( (a:a)  and  (b:b) ) {s{a:a}}",
    "@supports not ((a:a) and (b:b)){s{a:a}}")
  ,("@supports ((yoyo: yaya) or (margin: 0) or (answer: 42)) { div { background-color:green; } }",
    "@supports ((yoyo:yaya) or (margin:0) or (answer:42)){div{background-color:green}}")
  ,("@supports (margin: 0) {@media  not  all { div { background-color:red; }}}",
    "@supports (margin:0){@media not all{div{background-color:red}}}")
  -- ,("@document url(http://www.w3.org/) , url-prefix(http://www.w3.org/Style/),\
  --             \ domain(mozilla.org), regexp(\"https:.*\")"
  -- ,("@document url(http://www.w3.org/),url-prefix(http://www.w3.org/Style/),\
    --           \domain(mozilla.org),regexp(\"https:.*\")"
  -- ,("@page { margin: 1in }",
  --   "@page{margin:1in}")
  -- ,("@page :left { font-size: 20pt; }",
    -- "@page:left{font-size:20pt}")
  -- ,("@page toc, index { size:8.5in 11in; }",
    -- "@page toc,index{size:8.5in 11in}")
  -- ,("@viewport { min-width: 640px; max-width: 800px; }",
    -- "@viewport{min-width:640px;max-width:800px}")
  -- ,("@counter-style circled-alpha { system: fixed; symbols: Ⓐ Ⓑ Ⓒ; suffix: " "; }",
    -- "@counter-style circled-alpha{system:fixed;symbols:Ⓐ Ⓑ Ⓒ;suffix:" "}")
  -- ,("@font-feature-values Jupiter Sans { @swash { delicate: 1; flowing: 2; } }",
    -- "@font-feature-values Jupiter Sans{@swash{delicate:1;flowing:2}}",
  ]

collapseLonghandTests :: Spec
collapseLonghandTests =
    describe "TRBL Longhand collapsing" $
      mapM_ (matchSpec f) collapseLonghandsTestsInfo
  where f = (Declarations . collapse) <$> declarations

collapseLonghandsTestsInfo :: [(Text, Text)]
collapseLonghandsTestsInfo =
  [("margin-top:1px;margin-right:2px;margin-bottom:3px;margin-left:4px",
    "margin:1px 2px 3px 4px")
  ,("margin-left:4px;margin-bottom:3px;margin-right:2px;margin-top:1px;",
    "margin:1px 2px 3px 4px")
  ,("margin-left:4px;margin-bottom:3px;padding-top:0;margin-right:2px;margin-top:1px;",
    "padding-top:0;margin:1px 2px 3px 4px")
  ,("margin-bottom:3px;padding-top:0;margin-right:2px;margin-top:1px;",
    "margin-bottom:3px;padding-top:0;margin-right:2px;margin-top:1px")
  ,("padding-left:4px;padding-bottom:3px;padding-right:2px;padding-top:1px;",
    "padding:1px 2px 3px 4px")
  ,("border-left-color:#004;border-bottom-color:#003;border-right-color:#002;border-top-color:#001;",
    "border-color:#001 #002 #003 #004")
  ]


spec :: Spec
spec = do atRuleTests
          combineAdjacentMediaQueriesTests
          collapseLonghandTests
          mergeRulesTest

main :: IO ()
main = hspec spec
