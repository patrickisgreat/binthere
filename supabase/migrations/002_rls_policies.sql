-- 002_rls_policies.sql
-- Row Level Security: users can only access data within their household

-- Enable RLS on all tables
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE bins ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkout_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_attributes ENABLE ROW LEVEL SECURITY;

-- Helper function: check if user belongs to a household
CREATE OR REPLACE FUNCTION user_in_household(h_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM household_members
        WHERE household_id = h_id AND user_id = auth.uid()
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Households: members can read, only creator can create
CREATE POLICY "Members can view their households"
    ON households FOR SELECT
    USING (user_in_household(id));

CREATE POLICY "Authenticated users can create households"
    ON households FOR INSERT
    WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Owners can update their households"
    ON households FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM household_members
            WHERE household_id = id AND user_id = auth.uid() AND role = 'owner'
        )
    );

-- Household members: members can view, owner/admin can manage
CREATE POLICY "Members can view household members"
    ON household_members FOR SELECT
    USING (user_in_household(household_id));

CREATE POLICY "Can insert own membership"
    ON household_members FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Owners can manage members"
    ON household_members FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM household_members AS hm
            WHERE hm.household_id = household_members.household_id
            AND hm.user_id = auth.uid()
            AND hm.role IN ('owner', 'admin')
        )
    );

-- Invitations: household members can view, owner/admin can create
CREATE POLICY "Members can view invitations"
    ON invitations FOR SELECT
    USING (user_in_household(household_id));

CREATE POLICY "Admin+ can create invitations"
    ON invitations FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM household_members
            WHERE household_id = invitations.household_id
            AND user_id = auth.uid()
            AND role IN ('owner', 'admin')
        )
    );

-- Anyone can read invitations by code (for joining)
CREATE POLICY "Anyone can look up pending invitations by code"
    ON invitations FOR SELECT
    USING (status = 'pending');

CREATE POLICY "Invitees can accept invitations"
    ON invitations FOR UPDATE
    USING (status = 'pending')
    WITH CHECK (status = 'accepted');

-- Zones, Bins, Items, Checkout Records, Custom Attributes:
-- All follow the same pattern: household members can CRUD

-- Zones
CREATE POLICY "Members can view zones" ON zones FOR SELECT USING (user_in_household(household_id));
CREATE POLICY "Members can create zones" ON zones FOR INSERT WITH CHECK (user_in_household(household_id));
CREATE POLICY "Members can update zones" ON zones FOR UPDATE USING (user_in_household(household_id));
CREATE POLICY "Members can delete zones" ON zones FOR DELETE USING (user_in_household(household_id));

-- Bins
CREATE POLICY "Members can view bins" ON bins FOR SELECT USING (user_in_household(household_id));
CREATE POLICY "Members can create bins" ON bins FOR INSERT WITH CHECK (user_in_household(household_id));
CREATE POLICY "Members can update bins" ON bins FOR UPDATE USING (user_in_household(household_id));
CREATE POLICY "Members can delete bins" ON bins FOR DELETE USING (user_in_household(household_id));

-- Items
CREATE POLICY "Members can view items" ON items FOR SELECT USING (user_in_household(household_id));
CREATE POLICY "Members can create items" ON items FOR INSERT WITH CHECK (user_in_household(household_id));
CREATE POLICY "Members can update items" ON items FOR UPDATE USING (user_in_household(household_id));
CREATE POLICY "Members can delete items" ON items FOR DELETE USING (user_in_household(household_id));

-- Checkout records
CREATE POLICY "Members can view checkouts" ON checkout_records FOR SELECT USING (user_in_household(household_id));
CREATE POLICY "Members can create checkouts" ON checkout_records FOR INSERT WITH CHECK (user_in_household(household_id));
CREATE POLICY "Members can update checkouts" ON checkout_records FOR UPDATE USING (user_in_household(household_id));

-- Custom attributes
CREATE POLICY "Members can view attributes" ON custom_attributes FOR SELECT USING (user_in_household(household_id));
CREATE POLICY "Members can create attributes" ON custom_attributes FOR INSERT WITH CHECK (user_in_household(household_id));
CREATE POLICY "Members can update attributes" ON custom_attributes FOR UPDATE USING (user_in_household(household_id));
CREATE POLICY "Members can delete attributes" ON custom_attributes FOR DELETE USING (user_in_household(household_id));

-- Storage bucket for images (create via Supabase dashboard)
-- Bucket name: 'item-images'
-- Policy: authenticated users can upload/read within their household path
