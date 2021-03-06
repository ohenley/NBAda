-------------------------------------------------------------------------------
--  Lock-based Stack - A lock-based concurrent stack.
--  Copyright (C) 2005 - 2007  Anders Gidenstam
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--
-------------------------------------------------------------------------------
--                              -*- Mode: Ada -*-
--  Filename        : lock_based_stack.ads
--  Description     : A lock-based concurrent stack.
--  Author          : Anders Gidenstam
--  Created On      : Fri Sep 23 17:55:38 2005
--  $Id: lock_based_stack.ads,v 1.2 2007/09/11 12:27:50 andersg Exp $
-------------------------------------------------------------------------------

pragma License (GPL);

with NBAda.Process_Identification;

generic
   type Element_Type is private;
   --  Element type.
   with package Process_Ids is
     new NBAda.Process_Identification (<>);
   --  Process identification.
package Lock_Based_Stack is

   ----------------------------------------------------------------------------
   --  Lock-based Stack.
   ----------------------------------------------------------------------------
   type Stack_Type is limited private;

   Stack_Empty : exception;

   procedure Push (On      : in out Stack_Type;
                   Element : in     Element_Type);
   procedure Pop  (From    : in out Stack_Type;
                   Element :    out Element_Type);
   function  Pop  (From    : access Stack_Type)
                  return Element_Type;

   function  Top  (From    : access Stack_Type)
                  return Element_Type;

private

   type Stack_Node;
   type Stack_Node_Access is access all Stack_Node;

   type Stack_Node is
      record
         Element : Element_Type;
         Next    : Stack_Node_Access;
      end record;

   type Stack_Type is
     limited record
        Head : Stack_Node_Access;
        Lock : aliased Integer := 1;
        pragma Atomic (Lock);
     end record;

end Lock_Based_Stack;
