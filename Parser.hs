module Parser
(parse) where

import ParserTypes
import ParseTree

import qualified Data.Map as Map
import qualified Data.Set as Set

type FirstSet = Set.Set Terminal
type FirstSetMap = Map.Map NonTerminal FirstSet

-- Every parse func will return bool flag showing
-- is parsing ok or not
-- And node of that function in Parse Tree
type ParseOutput = ([Terminal], Bool, ParseTree)

-- Check if input token is one of nonterminal first set
inFirstSet :: NonTerminal -> Terminal -> Bool
inFirstSet nterm term = False 

-- TermInt TermId TermBackQuote

parse :: NonTerminal -> [Terminal] -> ParseOutput
parse Program ts
    | statusDeclList = (streamDeclList, True, NodeProgramm ptDeclList)
    | otherwise = (ts, False, NodeProgramm ptDeclList)
  where
    (streamDeclList, statusDeclList, ptDeclList) = parse DeclList ts

parse DeclList ts
    | statusDecl = case statusDeclList of
                       True -> (streamNodeDeclList, True, NodeDeclList ptDecl ptDeclList)
                       _    -> onError
    | otherwise = onError
  where
    (streamDecl, statusDecl, ptDecl) = parse Decl ts
    (streamNodeDeclList, statusDeclList, ptDeclList) = parse DeclListN streamDecl
    onError = (ts, False, NodeDeclList ptDecl ptDeclList)

parse DeclListN ts@(t:stream)
    | inFirstSet DeclListN t = 
        case statusDecl of
            True -> case statusDeclListN of
                        True -> (streamDeclListN, True, NodeDeclListN ptDecl ptDeclListN)
                        _    -> (ts, False, NodeDeclListN EmptyTree EmptyTree)
            _    -> (ts, False, NodeDeclListN EmptyTree EmptyTree) 
    | otherwise = (ts, True, NodeDeclListN EmptyTree EmptyTree)
  where
    (streamDecl, statusDecl, ptDecl) = parse Decl ts
    (streamDeclListN, statusDeclListN, ptDeclListN) = ([], True, EmptyTree)

parse Decl ts
    | statusVarDecl = (streamVarDecl, True, treeNode ptVarDecl)
    | statusFuncDecl = (streamFuncDecl, True, treeNode ptFuncDecl)
    | otherwise = (ts, False, treeNode ptVarDecl) 
  where
    treeNode = NodeDecl
    (streamVarDecl, statusVarDecl, ptVarDecl) = parse VarDecl ts
    (streamFuncDecl, statusFuncDecl, ptFuncDecl) = parse FuncDecl ts

parse VarDecl ts
    | statusTypeSpec = case statusVarDeclList of
                           True -> 
                               case streamVarDeclList of
                                   (TermBackQuote:xs) -> (xs, True, 
                                                          NodeVarDecl ptTypeSpec ptVarDeclList TermBackQuote)
                                   _                  -> onError
                           _    -> onError
    | otherwise = onError
  where
    onError = (ts, False, NodeVarDecl ptTypeSpec ptVarDeclList TermEmpty)
    (streamTypeSpec, statusTypeSpec, ptTypeSpec) = parse TypeSpec ts
    (streamVarDeclList, statusVarDeclList, ptVarDeclList) = parse VarDeclList streamTypeSpec

parse ScopedVarDecl ts@(t:stream)
    | t == TermStatic = 
        let (streamTypeSpec, statusTypeSpec, ptTypeSpec) = parse TypeSpec stream
            (streamVarDeclList, statusVarDeclList, ptVarDeclList) = parse VarDeclList streamTypeSpec
        in case head streamVarDeclList of 
               TermBackQuote -> (tail streamVarDeclList, True, treeNode TermStatic ptTypeSpec ptVarDeclList TermBackQuote)
               _             -> onError
    | otherwise = 
        let (streamTypeSpec, statusTypeSpec, ptTypeSpec) = parse TypeSpec ts
            (streamVarDeclList, statusVarDeclList, ptVarDeclList) = parse VarDeclList streamTypeSpec
        in case head streamVarDeclList of
               TermBackQuote -> (tail streamVarDeclList, True, 
                                 treeNode TermEmpty ptTypeSpec ptVarDeclList TermBackQuote)
               _             -> onError
  where
    onError = (ts, False, treeNode TermEmpty EmptyTree EmptyTree TermEmpty)
    treeNode = NodeScopedVarDecl 

parse TypeSpec ts@(t:stream)
    | t == TermInt = (stream, True, treeNode TermInt)
    | t == TermBool = (stream, True, treeNode TermBool)
    | t == TermChar = (stream, True, treeNode TermChar)
    | otherwise = (ts, False, treeNode TermEmpty)
  where
    treeNode = NodeTypeSpec

parse VarDeclList ts@(t:stream)
    | statusVarDeclInit = case statusVarDeclListN of
                              True -> (streamVarDeclListN, True, NodeVarDeclList ptVarDeclInit ptVarDeclListN)
                              _    -> onError
    | otherwise = onError
  where
    onError = (ts, False, NodeVarDeclList EmptyTree EmptyTree)
    (streamVarDeclInit, statusVarDeclInit, ptVarDeclInit) = parse VarDeclInit ts
    (streamVarDeclListN, statusVarDeclListN, ptVarDeclListN) = parse VarDeclListN streamVarDeclInit

parse VarDeclListN ts@(t:stream)
    | t == TermComma = case statusVarDeclInit of
                           True -> case statusVarDeclListN of
                                       True -> (streamVarDeclListN, True, 
                                                NodeVarDeclListN TermComma ptVarDeclInit ptVarDeclListN)
                                       _    -> onError
                           _    -> onError 
    | otherwise = (ts, True, NodeVarDeclListN TermEmpty EmptyTree EmptyTree)
  where
    onError = (ts, False, NodeVarDeclListN TermEmpty EmptyTree EmptyTree)
    (streamVarDeclInit, statusVarDeclInit, ptVarDeclInit) = parse VarDeclInit stream
    (streamVarDeclListN, statusVarDeclListN, ptVarDeclListN) = parse VarDeclListN streamVarDeclInit

parse VarDeclInit ts
    | statusVarDeclId = case streamVarDeclId of
                          (TermColon:xs) -> case statusSimpleExpr of
                                                True -> (streamSimpleExpr, True,
                                                         treeNode ptVarDeclId TermColon ptSimpleExpr)
                                                _    -> onError
                          _              -> (streamVarDeclId, True, treeNode ptVarDeclId TermEmpty EmptyTree)
    | otherwise = onError
  where
    onError = (ts, False, treeNode EmptyTree TermEmpty EmptyTree)
    treeNode = NodeVarDeclInit
    (streamVarDeclId, statusVarDeclId, ptVarDeclId) = parse VarDeclId ts
    (streamSimpleExpr, statusSimpleExpr, ptSimpleExpr) = parse SimpleExpr (tail streamVarDeclId)

parse VarDeclId ts@(t:nt:stream)
    | t == TermId = case nt of
                         TermLSqBracket -> case stream of
                                               (TermNumConst:TermRSqBracket:xs) -> 
                                                   (xs, True, 
                                                   NodeVarDeclId TermId TermLSqBracket TermNumConst TermRSqBracket)
                                               _                            -> onError
                         _              -> (nt:stream, True, NodeVarDeclId TermId TermEmpty TermEmpty TermEmpty)
    | otherwise = onError

  where 
    onError = (ts, False, EmptyTree)

parse FuncDecl ts = (ts, True, EmptyTree)

parse x [] = error "Send empty list of tokens to function"
--parse FuncDecl ts = 
--    let ((t':nt':stream'), status', err', ptTypeSpec) = parse TypeSpec ts
--    in case t' of
--           TermId -> case nt' of
--                         TermLParen -> let ((t'':stream''), status'', err'', ptParms) = parse Parms stream'
--                                       in case t'' of
--                                              TermRParen -> parse Stmt stream''
--                                              _          -> (t'':stream'', False, 
--                                                             "Missing right brace in func decl", EmptyTree)
--                           _        -> (nt:stream', False, "Missing left brace in func declaration", EmptyTree) 
--           _      -> (t':nt':stream', False, "Missing ID afte type specification", EmptyTree)
--
--parse Parms ts = 
--    let (stream', status', err', prParmList) = parse ParmList ts
--    in case status' of
--           True -> (stream', status', err', ptParmList)
--           False -> (stream', True, "", EmptyTree)  
--
--parse ParmList ts = 
--    let (stream', status', err', prParmTypeList) = parse ParmTypeList ts
--        (stream'', status'', err'', prParmListN) = parse ParmListN stream'
--    in (stream'', status' && status'', err' ++ err'', NodeParmList prParmTypeList prParmListN)
--
--parse ParmListN ts@(t:stream) =
--    case t of
--        TermComma -> let (stream', status', err', prParmTypeList) = parse ParmTypeList stream
--                         (stream'', status'', err'', prParmListN) = parse ParmListN stream'
--                     in (stream'', status'  && status'', err' ++ err'', NodeParmListN prParmTypeList prParmListN)
--        _         -> (ts, True, "", EmptyTree)
--
--parse ParmTypeList ts = 
--    let (stream', status', err', prTypeSpec) = parse TypeSpec ts
--        (stream'', status'', err'', prParmId) = parse ParmId stream'
--    in (stream'', status' && status'', err' ++ err'', NodeParmTypeList  prTypeSpec prParmId)
--
--parse ParmId ts@(t:nt:nnt:stream) = 
--    | t == TermId = case nt of
--                        TermLSqBracket -> case nnt of
--                                              TermRSqBracket -> (stream, True, "", NodeParmId t nt nnt)
--                                              _              -> (nnt:stream, False, "Missing right square bracket", NodeParmId t nt EmptyTree)
--                      _              -> (nt:nnt:stream, True, "", NodeParmId t EmptyTree EmptyTree EmptyTree)
--    | otherwise = (ts, False, "Miss match parm id", EmptyTree)
--
--parse Stmt ts 
--    | status' = parse'
--    | status'' = parse''
--    | status''' = parse'''
--    | status'''' = parse''''
--    | status''''' = parse'''''
--    | otherwise = (ts, False, "Failed to parse one of the statement form", EmptyTree)
--  where
--    parse' = parse ExprStmt ts
--    (stream', status', err', ptExprStmt) = parse'
--
--    parse'' = parse CompoundStmt stream'
--    (stream'', status'', err'', prCompoundStmt) = parse''
--
--    parse''' = parse IterStmt stream''
--    (stream''', satus''', err''', prIterStmt) = parse'''
--
--    parse'''' = parse ReturnStmt stream'''
--    (stream'''', status'''', err'''', ptReturnStmt) = parse''''
--
--    parse''''' = parse BreakStmt stream''''
--    (stream''''', status''''', err''''', ptReturnStmt) = parse'''''
--
--parse ExprStmt ts@(t:stream)
--    | status' = case t' of 
--                    TermColon -> (stream', True, "", NodeExprStmt ptExpr t)
--                    _         -> (t':stream', False, "Missing colon after expr", EmptyTree)
--    | otherwise = case t of
--                      TermColon -> (stream, True, "", NodeExprStmt EmptyTree t)
--                      _         -> (ts, False, "Missing colon in stmt", EmptyTree)
--    let (stream', status', err', prExpr) = parse Expr ts
--    in case of
--  where
--    parse' = parse Expr ts
--    ((t':stream'), status', err', prExpr) = parse Expr ts
--
--parse CompoundStmt ts@(t:stream)
--    | t == TermLBrace = case status' of 
--                            True -> case status'' of
--                                        True -> case head stream'' of
--                                                    TermRBrace -> (stream'', True, "", 
--                                                                   NodeCompoundStmt ptLocalDecls ptStmtList)
--                                                    _          -> (stream'', False, 
--                                                                   "Missing right brace after stmt list", EmptyTree)
--                                        _    -> (stream', status'', err'', EmptyTree)
--                            _    -> (stream, status', err', EmptyTree)
--    | otherwise = (ts, False, "Missing left brace in compound statement", EmptyTree)
--  where
--    parse' = parse LocalDecls stream
--    (stream', status', err', ptLocalDecls) = parse'
--
--    parse'' = parse StmtList stream'
--    (stream'', status'', err'', ptStmtList) = parse''
--
--parse StmtList ts =
--    | status' = case status' of
--                    True -> parse''
--                    False -> (stream', False, err'', EmptyTree)
--    | otherwise = (ts, False, err', EmptyTree)
--  where
--    parse' = parse Stmt ts
--    (stream', status', err', ptStmt) = parse'
--
--    parse'' = parse StmtListN stream'
--    (stream'', status'', err'', ptStmtListN) = parse''
--
--parse StmtListN ts
--    | status' = parse'
--    | otherwise = (ts, True, "", NodeStmtListN EmptyTree)
--  where
--    parse' = parse Stmt ts
--    (stream', status', err', ptStmt) = parse'
--
--parse LocalDecl ts
--    | status' = case status'' of
--                    True -> (stream'', True, "", NodeLocalDecl ptScopedVarDecl ptLocalDeclN) 
--                    _    -> (stream', status'', err'', EmptyTree)
--    | otherwise = (ts, True, "", EmptyTree)
--  where
--    parse' = parse ScopedVarDecl ts
--    (stream', status', err', ptScopedVarDecl) = parse'
--
--    parse'' = parse LocadDeclN stream'
--    (stream'', status'', err'', ptLocalDeclN) = parse''
--
--parse LocalDeclN ts
--    | status' = case status'' of
--                    True -> (stream'', True, NodeLocalDecl ptScopedVarDecl ptLocalDeclN) 
--                    _    -> error "Failed to parse LocalDeclN"
--    | otherwise = (ts, True, EmptyTree)
--  where
--    parse' = parse ScopedVarDecl ts
--    (stream', status', ptScopedVarDecl) = parse'
--
--    parse'' = parse LocadDeclN stream'
--    (stream'', status'', ptLocalDeclN) = parse''
--
--parse IterStmt ts@(t:nt:stream)
--    | t == TermWhile = case nt of
--                           TermLParen -> 
--                               case statusSE of
--                                   True -> 
--                                       case head streamSE of
--                                           True -> 
--                                               case statusStmt of
--                                                   True -> (streamStmt, True, 
--                                                            NodeIterStmt t nt ptSimpleExpr (head streamSE) ptStmt)
--                                                   _    -> (ts, False, EmptyTree)
--                                           other-> 
--                                               (ts, False, EmptyTree)
--                                    _   ->
--                                        (ts, False, EmptyTree)
--                            other     ->
--                                (ts, False, EmptyTree)
--    | otherwise = (ts, False, EmptyTree)
--  where
--    parseSE = parse SimpleExpr stream
--    (streamSE, statusSE, ptSimplExpr) = parseSE
--
--    parseStmt = parse Stmt tail streamSE
--    (streamStmt, statusStmt, ptStmt) = parseStmt
--
--parse ReturnStmt ts@(t:nt:stream)
--    | t == TermReturn = case statusExpr of
--                            True -> case head streamExpr of
--                                        TermColon -> (tail streamExpr, True, treeNode t ptExpr (head streamExpr))
--                                        _         -> (ts, False, EmptyTree)
--                            False -> case nt of
--                                         TermColon -> (stream, True, treeNode t nt)
--                                         _         -> (ts, False, EmptyTree)
--    | otherwise = (ts, False, EmptyTree)
--                            
--  where
--    parseExpr = parse Expr ts
--    (streamExpr, statusExpr, ptExpr) = parseExpr
--    treeNode = NodeReturnStmt
--
--parse BreakStmt ts@(t:nt:stream)
--    | t == TermBreak = case nt of
--                           TermColon -> (stream, True, NodeBreakStmt t nt)
--                           _         -> (ts, False, EmptyTree)
--    | otherwise = (ts, False, EmptyTree)
--
--parse Expr ts@(t:stream)
--    | statusMutable = case head streamMutable of
--                          TermEqual -> case statusExpr of
--                                           True -> (streamExpr, True, treeNode ptMutable TermEqual ptExpr)
--                                           _    -> (ts, False, EmptyTree)
--                          TermIncrement -> (tail streamMutable, True, treeNode ptMutable TermIncrement TermEmpty)
--                          TermDecrement -> (tail streamMutable, True, treeNode ptMutable TermDecrement TermEmpty)
--                          _             -> (ts, False, EmptyTree)
--    | statusSimpleExpr = (streamSimpleExpr, True, treeNode ptSimpleExpr TermEmpty TermEmpty)
--  where
--    treeNode = NodeExpr
--    (streamMutable, statusMutable, ptMutable) = parse Mutable ts
--    (streamExpr, statusExpr, ptExpr) = parse Expr tail streamMutable
--    (tsSimpleExpr, statusSimpleExpr, ptSimpleExpr) = parse SimpleExpr ts
--
--parse SimpleExpr ts
--    | statusAndExpr = case statusSimpleExpr of
--                          True -> (streamSimpleExpr, True, NodeSimpleExpr ptAndExpr ptSimpleExpr)
--                          _    -> (ts, False, EmptyTree)
--    | otherwise = (ts, False, EmptyTree)
--  where
--    (streamAndExpr, statusAndExpr, ptAndExpr) = parse AndExpr ts
--    (streamSimpleExpr, statusSimpleExpr, ptSimpleExpr) = parse SimpleExpr streamAndExpr
--
--parse SimpleExprN ts@(t:stream)
--    | t == TermOr = case statusAndExpr of
--                        True -> case statusSimpleExpr of
--                                    True -> (streamSimpleExpr, True, 
--                                             NodeSimpleExpr ptAndExpr ptSimpleExpr)
--                                    _    -> (ts, False, EmptyTree)
--                        _    -> (ts, False, EmptyTree) 
--    | otherwise = (ts, True, EmptyTree)
--  where
--    (streamAndExpr, statusAndExpr, ptAndExpr) = parse AndExpr ts
--    (streamSimpleExpr, statusSimpleExpr, ptSimpleExpr) = parse SimpleExpr streamAndExpr
--
--parse AndExpr ts
--    | statusUnaryRelExpr = case statusAndExpr of
--                               True -> (streamAndExpr, True, NodeAndExpr ptUnaryRelExpr ptAndExpr)
--                               _    -> (ts, False, EmptyTree)
--    | otherwise = (ts, False, EmptyTree)
--  where
--    (streamUnaryRelExpr, statusUnaryRelExpr, ptUnaryRelExpr) = parse UnaryRelExpr ts
--    (streamAndExpr, statusAndExpr, ptAndExpr) = parse AndExpr streamUnaryRelExpr



parse SimpleExpr ts = (ts, True, NodeSimpleExpr EmptyTree EmptyTree)

--parse FuncDecl ts = 
--    let
--        (stream', b1, er1, ptTypeSpec) = parse TypeSpec ts
--        (stream'', b2)                 = (tail stream') (head stream' == TokenID) 
--        (stream''', b3)                = (tail stream'') (head stream'' == TokenLParen)
--        (stream'''', b4, er4, ptParms) = parse Parms stream'''
--        (stream''''', b5)              = (tail stream'''') (head stream'''' == TokenRParen)
--        (stream'''''', b6)             = parse Stmt stream'''''
--    in (stream'''''', b1 && b2 && b3 && b4 && b5 && b6, er4, NodeFuncDecl)
--
--parse Parms ts@(t:st) =
--    | inFirstSet Parms t = 
--        let (st', b1, pt) = parse ParmList ts
--        in (st', b1, NodeParms pt)
--    | otherwise = (ts, NodeParms TermEpsilon)
--
--parse ParmList ts@(t:st) = 
--    (ts, True, NodeParmList EmptyNode EmptyNode)
