-- ============================================================
-- My Chain Link - Messaging Setup (Supabase SQL Editor)
-- Run this in your Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- 1. Conversations table (for DMs)
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_1 UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  participant_2 UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  last_message_text TEXT,
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(participant_1, participant_2)
);

-- 2. Messages table
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for conversations
CREATE POLICY "conv_select" ON conversations FOR SELECT USING (auth.uid() = participant_1 OR auth.uid() = participant_2);
CREATE POLICY "conv_insert" ON conversations FOR INSERT WITH CHECK (auth.uid() = participant_1 OR auth.uid() = participant_2);
CREATE POLICY "conv_update" ON conversations FOR UPDATE USING (auth.uid() = participant_1 OR auth.uid() = participant_2);

-- 5. RLS Policies for messages
CREATE POLICY "messages_select" ON messages FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "messages_delete" ON messages FOR DELETE USING (auth.uid() = sender_id);

-- 6. Function: get_or_create_conversation
CREATE OR REPLACE FUNCTION get_or_create_conversation(user1 UUID, user2 UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  conv_id UUID;
BEGIN
  SELECT id INTO conv_id FROM conversations
  WHERE (participant_1 = user1 AND participant_2 = user2)
     OR (participant_1 = user2 AND participant_2 = user1);
  
  IF conv_id IS NULL THEN
    INSERT INTO conversations (participant_1, participant_2)
    VALUES (user1, user2)
    RETURNING id INTO conv_id;
  END IF;
  
  RETURN conv_id;
END;
$$;

-- 7. Function + Trigger: auto-update last_message
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE conversations
  SET last_message_text = NEW.content,
      last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_new_message ON messages;

CREATE TRIGGER on_new_message
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION update_conversation_last_message();

-- 8. Enable realtime for live chat
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- 9. Performance indexes
CREATE INDEX IF NOT EXISTS idx_messages_conv_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
