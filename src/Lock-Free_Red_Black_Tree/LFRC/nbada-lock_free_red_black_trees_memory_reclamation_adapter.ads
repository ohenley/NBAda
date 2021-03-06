-------------------------------------------------------------------------------
--  Lock-Free Red Black Trees - An implementation of the lock-free red black
--                              tree algorithm by A. Gidenstam.
--
--  Copyright (C) 2008  Anders Gidenstam
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
pragma Style_Checks (Off);
-------------------------------------------------------------------------------
--                              -*- Mode: Ada -*-
--  Filename        : nbada-lock_free_deques_memory_reclamation_adapter.ads
--  Description     : An Ada implementation of the lock-free deque algorithm
--                    by H. Sundell and P. Tsigas.
--  Author          : Anders Gidenstam
--  Created On      : Thu Sep  6 11:48:14 2007
--  $Id: nbada-lock_free_red_black_trees_memory_reclamation_adapter.ads,v 1.1 2008/02/26 16:55:14 andersg Exp $
-------------------------------------------------------------------------------
pragma Style_Checks (All_Checks);

pragma License (GPL);

with NBAda.Lock_Free_Reference_Counting;
with NBAda.Process_Identification;

generic

   with package Process_Ids is
     new NBAda.Process_Identification (<>);
   --  Process identification.

package NBAda.Lock_Free_Red_Black_Trees_Memory_Reclamation_Adapter is

   package Memory_Reclamation is new NBAda.Lock_Free_Reference_Counting
     (Max_Number_Of_Guards => 128);

end NBAda.Lock_Free_Red_Black_Trees_Memory_Reclamation_Adapter;
