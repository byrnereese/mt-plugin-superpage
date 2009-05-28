# SuperPage Plugin for Movable Type
# Author: Byrne Reese <byrne at majordojo.com>
# License: Artistic

OVERVIEW

This plugin was created in support of Movable Type's documentation
effort. It will take a single page formatted in Markdown and convert
into a set of pages complete with a table of contents. 

Each "child page" is delineated by a HTML header. 

USAGE

* To mark a page as a "super page" edit the page in question and under
  "Publishing" toggle the "Super Page?" checkbox. Then save the page
  and the child pages will be created for you automatically.
* When you delete a super page, all of the child pages will be
  deleted as well. This cannot be undone.
* Child pages will inherit all of the parent page's properties vis-a-
  vis commenting.
* A table of contents page with a basename of 'index' will be created
  for you automatically in markdown.

CAVEATS

* All headings, which map to the titles of each child page must be
  unique. When you change a heading, and thus a page title, comments
  on that child page will be permanently deleted.
  PLEASE BE CAREFUL if you want to preserve these comments.

TEMPLATE TAGS

Super Page makes the following template tags available to help construct
navigation links between pages.

* IsSuperChildPage - returns true if the current page is the artifact of a super page
* IsSuperPage - returns true if the current page is a super/parent page
* PrevPageID - returns the page ID of the previous page in the super page
* NextPageID - returns the page ID of the next page in the super page
* ParentPageID - returns the page ID of the parent super page

EXAMPLE

Let's suppose I have a super page called "Test Page" who contents are:

  # Header 1
  
  yadda yadda yadda
  
  ## Header 2
  
  yadda yadda yadda
  
  ### Header 3
  
  yadda yadda yadda
  
  ## Header 2b
  
  yadda yadda yadda

The pages that will result are:

* Header 1
* Header 2
* Header 3
* Header 2b
* Test Page: Table of Contents

SAMPLE TEMPLATE CODE

<mt:IsSuperChildPage>
<p>This is a super page!</p>
<ul>
<mt:if tag="NextPageID" ne="">
  <li>Next: <mt:NextPageID setvar="next">
    <mt:Pages id="$next"><a href="<mt:PagePermalink>"><mt:PageTitle></a></mt:Pages></li>
</mt:if>
<mt:if tag="PrevPageID" ne="">
  <li>Prev: <mt:PrevPageID setvar="prev">
    <mt:Pages id="$prev"><a href="<mt:PagePermalink>"><mt:PageTitle></a></mt:Pages></li>
</mt:if>
  <li>Parent: <mt:ParentPageID setvar="parent">
    <mt:Pages id="$parent"><a href="<mt:PagePermalink>"><mt:PageTitle></a></mt:Pages></li>
</ul>
</mt:IsSuperChildPage>
