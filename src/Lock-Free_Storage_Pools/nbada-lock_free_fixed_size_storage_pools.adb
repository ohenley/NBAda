-------------------------------------------------------------------------------
--  Lock-free fixed size storage pool.
--  Copyright (C) 2003 - 2012  Anders Gidenstam
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
pragma Style_Checks (OFF);
-------------------------------------------------------------------------------
--                              -*- Mode: Ada -*-
--  Filename        : lock_free_fixed_size_storage_pools.adb
--  Description     : A lock-free fixed size storage pool implementation.
--  Author          : Anders Gidenstam
--  Created On      : Thu Apr  3 17:50:52 2003
-------------------------------------------------------------------------------
pragma Style_Checks (ALL_CHECKS);

pragma License (GPL);

with Ada.Unchecked_Deallocation;
with System.Address_To_Access_Conversions;
with NBAda.Primitives;

package body NBAda.Lock_Free_Fixed_Size_Storage_Pools is

   ----------------------------------------------------------------------------
   type Pool_Block_Access is access all Pool_Block;

   function To_Block_Access (X    : Pool_Block_Ref;
                             Pool : Lock_Free_Aligned_Storage_Pool)
                            return Pool_Block_Access;
   function To_Block_Ref    (X    : Pool_Block_Access;
                             Ver  : Version_Number;
                             Pool : Lock_Free_Aligned_Storage_Pool)
                            return Pool_Block_Ref;
   function Is_Null (X : Pool_Block_Ref) return Boolean;

   procedure Free is
      new Ada.Unchecked_Deallocation (Atomic_Storage_Array,
                                      Storage_Array_Access);
   function CAS is new
     Primitives.Boolean_Compare_And_Swap_32 (Pool_Block_Ref);

   ----------------------------------------------------------------------------
   package Pool_Blocks is
      new System.Address_To_Access_Conversions (Pool_Block);

   ----------------------------------------------------------------------------
   procedure Allocate
     (Pool                     : in out Lock_Free_Aligned_Storage_Pool;
      Storage_Address          :    out System.Address;
      Size_In_Storage_Elements : in     System.Storage_Elements.Storage_Count;
      Alignment                : in     System.Storage_Elements.Storage_Count)
   is
      use type System.Storage_Elements.Storage_Offset;

      Block : Pool_Block_Access;
   begin
      if Size_In_Storage_Elements > Pool.Block_Size then
         --  The requested block is too large.
         raise Storage_Error;
      end if;

      loop
         declare
            Block_Ref : constant Pool_Block_Ref := Pool.Free_List;
         begin
            if Is_Null (Block_Ref) then
               --  This storage pool is empty.
               raise Storage_Exhausted;
            end if;

            Block := To_Block_Access (Block_Ref, Pool);

            exit when CAS (Target    => Pool.Free_List'Access,
                           Old_Value => Block_Ref,
                           New_Value => (Block.Next.Index,
                                         Block_Ref.Version + 1));
         end;
      end loop;

      --  Safety check.
      if Integrity_Checking then
         declare
            Head : constant Pool_Block_Access :=
              To_Block_Access (Pool.Free_List, Pool);
            pragma Unreferenced (Head);
         begin
            null;
         end;
      end if;

      Storage_Address :=
        Pool_Blocks.To_Address (Pool_Blocks.Object_Pointer (Block));

      --  Safety check.
      if Integrity_Checking then
         declare
            use type System.Address;
         begin
            if
              Storage_Address /= Block.all'Address or
              Storage_Address mod Alignment /= 0
            then
               raise Implementation_Error;
            end if;
         end;
      end if;
   end Allocate;

   ----------------------------------------------------------------------------
   procedure Deallocate
     (Pool                     : in out Lock_Free_Aligned_Storage_Pool;
      Storage_Address          : in     System.Address;
      Size_In_Storage_Elements : in     System.Storage_Elements.Storage_Count;
      Alignment                : in     System.Storage_Elements.Storage_Count)
   is
      pragma Unreferenced (Size_In_Storage_Elements);
      pragma Unreferenced (Alignment);
      use type System.Address;

      Block : Pool_Block_Access;
   begin
      --  Safety check.
      if Integrity_Checking then
         if
           Storage_Address < Pool.Storage (Pool.Storage'First)'Address or
           Storage_Address > Pool.Storage (Pool.Storage'Last)'Address
         then
            raise Storage_Error;
         end if;
      end if;

      Block :=
        Pool_Block_Access (Pool_Blocks.To_Pointer (Storage_Address));

      --  Safety check.
      if Integrity_Checking then
         if Block.all'Address /= Storage_Address then
            raise Implementation_Error;
         end if;
      end if;

      loop
         declare
            Old_Head : constant Pool_Block_Ref := Pool.Free_List;
            New_Head : constant Pool_Block_Ref :=
              To_Block_Ref (Block, Old_Head.Version + 1, Pool);
         begin
            Block.Next := Old_Head;

            exit when CAS (Target    => Pool.Free_List'Access,
                           Old_Value => Old_Head,
                           New_Value => New_Head);
         end;
      end loop;

      --  Safety check.
      if Integrity_Checking then
         declare
            Head : constant Pool_Block_Access :=
              To_Block_Access (Pool.Free_List, Pool);
            pragma Unreferenced (Head);
         begin
            null;
         end;
      end if;
   end Deallocate;

   ----------------------------------------------------------------------------
   function Storage_Size (Pool : Lock_Free_Aligned_Storage_Pool)
                         return System.Storage_Elements.Storage_Count is
      use type System.Storage_Elements.Storage_Count;
   begin
      return Pool.Real_Block_Size *
        System.Storage_Elements.Storage_Count (Pool.Pool_Size);
   end Storage_Size;

   ----------------------------------------------------------------------------
   function Validate (Pool : Lock_Free_Aligned_Storage_Pool)
                     return Block_Count is
      use type System.Address;
      Block : Pool_Block_Access := To_Block_Access (Pool.Free_List, Pool);
      No_Of_Free : Block_Count := 0;
   begin
      while Block /= null loop
         if Block.all'Address < Pool.Storage (Pool.Storage'First)'Address or
            Block.all'Address > Pool.Storage (Pool.Storage'Last)'Address
         then
            raise Implementation_Error;
         end if;
         No_Of_Free := No_Of_Free + 1;
         Block := To_Block_Access (Block.Next, Pool);
      end loop;
      return No_Of_Free;
   end Validate;

   ----------------------------------------------------------------------------
   function Belongs_To (Pool            : Lock_Free_Aligned_Storage_Pool;
                        Storage_Address : System.Address)
                       return Boolean is
      use type System.Address;
   begin
      return
        Pool.Storage (Pool.Storage'First)'Address <= Storage_Address and
        Storage_Address < Pool.Storage (Pool.Storage'Last)'Address;
   end Belongs_To;

   ----------------------------------------------------------------------------
   --
   ----------------------------------------------------------------------------

   ----------------------------------------------------------------------------
   procedure Initialize (Pool : in out Lock_Free_Aligned_Storage_Pool) is
      use System.Storage_Elements;
   begin
      --  Reset free list.
      Pool.Free_List := Null_Ref;

      --  Compute real block size.
      Pool.Real_Block_Size :=
        Storage_Count'Max (Pool.Block_Size,
                           Pool_Block'Max_Size_In_Storage_Elements);
      --  Pad to correct alignment if necessary.
      if Pool.Real_Block_Size mod Pool.Alignment /= 0 then
         Pool.Real_Block_Size :=
           (Pool.Real_Block_Size / Pool.Alignment + 1) *
           Pool.Alignment;
      end if;
      --  Safety check.
      if Integrity_Checking then
         if Pool.Real_Block_Size mod Pool.Alignment /= 0 then
            raise Implementation_Error;
         end if;
      end if;

      --  Preallocate storage for the pool.
      Pool.Storage := new Atomic_Storage_Array
        (0 .. Storage_Count (Pool.Pool_Size) * Pool.Real_Block_Size +
              Pool.Alignment);
      --  Ensure that the blocks will be aligned.
      Pool.Storage_Offset :=
        Pool.Alignment - Pool.Storage (0)'Address mod Pool.Alignment;

      --  Safety check.
      if Integrity_Checking then
         if
           Pool.Storage (Pool.Storage_Offset)'Address mod Pool.Alignment /= 0
         then
            declare
               Address : System.Address :=
                 Pool.Storage (Pool.Storage_Offset)'Address;
            begin
               raise Implementation_Error;
            end;
         end if;
      end if;

      Primitives.Membar;

      --  Insert the new storage in the free list.
      for I in 0 .. Storage_Count (Pool.Pool_Size - 1) loop
         declare
            Block_Ref : constant Pool_Block_Ref := (Block_Index (I), 0);
            Block     : constant Pool_Block_Access :=
              To_Block_Access (Block_Ref, Pool);
            use type System.Address;
         begin
            --  Safety check.
            if Integrity_Checking then
               if Block.all'Address /=
                 Pool.Storage (Pool.Storage_Offset +
                               I * Pool.Real_Block_Size)'Address or
                 Block.all'Address mod Pool.Alignment /= 0
               then
                  raise Implementation_Error;
               end if;
            end if;

            --  Add block to free list.
            loop
               Block.Next := Pool.Free_List;

               exit when CAS (Target    => Pool.Free_List'Access,
                              Old_Value => Block.Next,
                              New_Value => Block_Ref);
            end loop;
         end;
      end loop;

      --  Safety check.
      if Integrity_Checking then
         if Validate (Pool) /= Pool.Pool_Size then
            raise Implementation_Error;
         end if;
      end if;
   end Initialize;

   ----------------------------------------------------------------------------
   procedure Finalize (Pool : in out Lock_Free_Aligned_Storage_Pool) is
   begin
      Primitives.Membar;
      Pool.Free_List := Null_Ref;
      Primitives.Membar;
      Free (Pool.Storage);
   end Finalize;

   ----------------------------------------------------------------------------
   function To_Block_Access (X    : Pool_Block_Ref;
                             Pool : Lock_Free_Aligned_Storage_Pool)
                            return Pool_Block_Access is
   begin
      if Is_Null (X) then
         return null;
      elsif Block_Count (X.Index) <= Pool.Pool_Size then
         declare
            use System.Storage_Elements;
            Block : constant Pool_Block_Access :=
              Pool_Block_Access
              (Pool_Blocks.To_Pointer
                 (Pool.Storage (Pool.Storage_Offset +
                                Storage_Count (X.Index) *
                                Pool.Real_Block_Size)'Address));
            --  Compute storage index where this block starts.  The
            --  selection of Real_Block_Size at initializtion time
            --  guarantees that the Pool_Block is properly aligned.
         begin
            --  Safety check.
            if Integrity_Checking then
               declare
                  use type System.Address;
               begin
                  if
                    Block.all'Address <
                    Pool.Storage (Pool.Storage'First)'Address
                    or
                    Block.all'Address >
                    Pool.Storage (Pool.Storage'Last)'Address
                  then
                     raise Implementation_Error;
                  end if;
               end;
            end if;

            return Block;
         end;
      else
         --  Invalid Block_Pool_Ref.
         raise Constraint_Error;
      end if;
   end To_Block_Access;

   ----------------------------------------------------------------------------
   function To_Block_Ref (X    : Pool_Block_Access;
                          Ver  : Version_Number;
                          Pool : Lock_Free_Aligned_Storage_Pool)
                         return Pool_Block_Ref is
      use System.Storage_Elements;

      Block_Ref : constant Pool_Block_Ref :=
        (Block_Index
           (Storage_Count
              ((To_Integer (X.all'Address) -
                To_Integer (Pool.Storage (Pool.Storage_Offset)'Address))) /
            Pool.Real_Block_Size),
         Ver);
   begin
      --  Safety check.
      if Integrity_Checking then
         if
           To_Integer (X.all'Address) -
           To_Integer (Pool.Storage (Pool.Storage_Offset)'Address) >
           Integer_Address (Pool.Storage'Length)
         then
            raise Implementation_Error;
         end if;
      end if;

      return Block_Ref;
   end To_Block_Ref;

   ----------------------------------------------------------------------------
   function Is_Null (X : Pool_Block_Ref) return Boolean is
   begin
      return X.Index = Block_Index'Last;
   end Is_Null;

end NBAda.Lock_Free_Fixed_Size_Storage_Pools;
