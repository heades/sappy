module SDF3.SpecValidation where

import SDF3.Spec
import Utils

import qualified Data.Set as Set

validateSpec :: Spec -> Bool
validateSpec spec@(Spec mod imps secs) = indexedAnd (validSection sorts) secs
  where
    sorts = specSorts spec

validSection :: SpecSorts -> Section -> Bool
validSection sorts (LexSyntax       prods)      = indexedAnd (validProduction (lexSorts sorts)) prods
validSection sorts (CFSyntax        prods)      = indexedAnd (validProduction (cfSorts sorts)) prods
validSection sorts (LexStartSymbols startSorts) = startSorts `Set.isSubsetOf` (lexSorts sorts)
validSection sorts (CFStartSymbols  startSorts) = startSorts `Set.isSubsetOf` (cfSorts sorts)
validSection sorts (TemplateOptions opts)       = indexedAnd (validTemplateOption (lexSorts sorts)) opts
validSection sorts (CFPriorities    prs)        = indexedAnd (validPriority (cfSorts sorts)) prs
validSection sorts (LexRestriction  rs)         = (sortsInRestriction rs) `Set.isSubsetOf` (cfSorts sorts)
validSection sorts (CFRestriction   rs)         = (sortsInRestriction rs) `Set.isSubsetOf` (cfSorts sorts)
validSection sorts _ = True

specSorts :: Spec -> SpecSorts
specSorts (Spec _ imps secs) = (importSpecSorts imps) `unionSpecSorts` (secSpecSorts secs)

secSpecSorts :: Set.Set Section -> SpecSorts
secSpecSorts secs
  = SpecSorts cfsorts lexsorts
  where
    cfsorts  = indexedUnion sectionCFSorts secs
    lexsorts = indexedUnion sectionLexSorts secs

importSpecSorts :: Set.Set Spec -> SpecSorts
importSpecSorts = indexedOp unionSpecSorts emptySpecSorts importSpecSort 
 where
   importSpecSort :: Spec -> SpecSorts
   importSpecSort ((Spec _ imps secs)) = (importSpecSorts imps) `unionSpecSorts` (secSpecSorts secs)

sectionCFSorts :: Section -> Set.Set Sort
sectionCFSorts (CFSorts sorts) = sorts
sectionCFSorts _ = Set.empty

sectionLexSorts :: Section -> Set.Set Sort
sectionLexSorts (LexSorts sorts) = sorts
sectionLexSorts _ = Set.empty                   

validProduction :: Set.Set Sort -> Production Sort -> Bool
validProduction sorts (Prod sort const sym _)
  = (sort `Set.member` sorts) && (symSorts `Set.isSubsetOf` sorts)
 where
   symSorts = sortsInSym sym
   
validProduction sorts (TemplateProd sort const tsym _) 
  = (sort `Set.member` sorts) && (tsymSorts `Set.isSubsetOf` sorts)
 where
   tsymSorts = sortsInTSym tsym

validTemplateOption :: Set.Set Sort -> TemplateOption Sort -> Bool
validTemplateOption sorts (AttrSym sort _) = sort `Set.member` sorts
validTemplateOption _ _ = True    

validPriority :: Set.Set Sort -> Priority Sort -> Bool
validPriority sorts (TransPriorityEl p1 p2)
  = (p1Sorts `Set.isSubsetOf` sorts) && (p2Sorts `Set.isSubsetOf` sorts)
  where
    p1Sorts = sortsInProdRefs p1
    p2Sorts = sortsInProdRefs p2
    
validPriority sorts (TransPriority p next)
  = (pSorts `Set.isSubsetOf` sorts) && (validPriority sorts next)
  where
    pSorts = sortsInProdRefs p
    
validPriority sorts (NontransPriorityEl p1 p2)
  = (p1Sorts `Set.isSubsetOf` sorts) && (p2Sorts `Set.isSubsetOf` sorts)
  where
    p1Sorts = sortsInProdRefs p1
    p2Sorts = sortsInProdRefs p2

validPriority sorts (NontransPriority p next)
  = (pSorts `Set.isSubsetOf` sorts) && (validPriority sorts next)
  where
    pSorts = sortsInProdRefs p
    
validPriority sorts (IndexTransPriorityEl p1 _ p2)
  = (p1Sort `Set.member` sorts) && (p2Sort `Set.member` sorts)
  where
    p1Sort = sortInProdRef p1
    p2Sort = sortInProdRef p2

validPriority sorts (IndexTransPriority p _ next)
  = (pSort `Set.member` sorts) && (validPriority sorts next)
  where
    pSort = sortInProdRef p
    
validPriority sorts (IndexNontransPriorityEl p1 _ p2)
  = (p1Sort `Set.member` sorts) && (p2Sort `Set.member` sorts)
  where
    p1Sort = sortInProdRef p1
    p2Sort = sortInProdRef p2

validPriority sorts (IndexNontransPriority p _ next)
  = (pSort `Set.member` sorts) && (validPriority sorts next)
  where
    pSort = sortInProdRef p
    
validPriority sorts (AttrTransPriorityEl (_, p1) (_, p2))
  = (p1Sorts `Set.isSubsetOf` sorts) && (p2Sorts `Set.isSubsetOf` sorts)
  where
    p1Sorts = sortsInProdRefs p1
    p2Sorts = sortsInProdRefs p2

validPriority sorts (AttrTransPriority (_, p) next)
  = (pSorts `Set.isSubsetOf` sorts) && (validPriority sorts next)
  where
    pSorts = sortsInProdRefs p
    
validPriority sorts (AttrNontransPriorityEl (_, p1) (_, p2))
  = (p1Sorts `Set.isSubsetOf` sorts) && (p2Sorts `Set.isSubsetOf` sorts)
  where
    p1Sorts = sortsInProdRefs p1
    p2Sorts = sortsInProdRefs p2

validPriority sorts (AttrNontransPriority (_, p) next)
  = (pSorts `Set.isSubsetOf` sorts) && (validPriority sorts next)
  where
    pSorts = sortsInProdRefs p

sortsInRestriction :: Set.Set (Restriction Sort) -> Set.Set Sort
sortsInRestriction = indexedUnion sortInRestriction

sortInRestriction :: Restriction Sort -> Set.Set Sort
sortInRestriction (Restrict sym _) = sortsInSym sym

sortsInProdRefs :: Set.Set (ProductionRef Sort) -> Set.Set Sort
sortsInProdRefs = indexedInsert sortInProdRef

sortInProdRef :: ProductionRef Sort -> Sort
sortInProdRef (ProdRef sort _) = sort

sortsInSym :: Symbol Sort -> Set.Set Sort
sortsInSym (SortSym sort)          = Set.singleton sort
sortsInSym (ListSym sym _)         = sortsInSym sym
sortsInSym (OptionalSym sym)       = sortsInSym sym
sortsInSym (Sequence sym1 sym2)    = (sortsInSym sym1) `Set.union` (sortsInSym sym2)
sortsInSym (Alternative sym1 sym2) = (sortsInSym sym1) `Set.union` (sortsInSym sym2)
sortsInSym _ = Set.empty

sortsInTSym :: TemplateSymbol Sort -> Set.Set Sort
sortsInTSym (TLitSort sort)         = Set.singleton sort
sortsInTSym (TOptSort sort)         = Set.singleton sort
sortsInTSym (TListSym tsym _ _)     = sortsInTSym tsym
sortsInTSym (TSequence tsym1 tsym2) = (sortsInTSym tsym1) `Set.union` (sortsInTSym tsym2)
sortsInTSym _                       = Set.empty
