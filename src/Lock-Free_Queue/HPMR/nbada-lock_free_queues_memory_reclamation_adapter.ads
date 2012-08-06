-------------------------------------------------------------------------------
--  Lock-free Queue - An implementation of Michael and Scott's lock-free queue.
--  Copyright (C) 2007 - 2012  Anders Gidenstam
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
--  Filename        : nbada-lock_free_queues_memory_reclamation_adapter.ads
--  Description     : An Ada implementation of Michael and Scott's
--                    lock-free queue algorithm.
--  Author          : Anders Gidenstam
--  Created On      : Wed Sep  5 13:50:28 2007
-------------------------------------------------------------------------------
pragma Style_Checks (All_Checks);

pragma License (GPL);

with NBAda.Memory_Reclamation.Hazard_Pointers;
with NBAda.Process_Identification;

generic

   with package Process_Ids is
     new NBAda.Process_Identification (<>);
   --  Process identification.

package NBAda.Lock_Free_Queues_Memory_Reclamation_Adapter is

   package Memory_Reclamation is new NBAda.Memory_Reclamation.Hazard_Pointers
     (Max_Number_Of_Dereferences => 3,
      Process_Ids                => Process_Ids);

end NBAda.Lock_Free_Queues_Memory_Reclamation_Adapter;
