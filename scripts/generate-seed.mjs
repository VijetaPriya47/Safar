import { randomUUID } from 'crypto'
import { writeFileSync } from 'fs'

// ── Helpers ──────────────────────────────────────────────────────────────────

const pick = (arr) => arr[Math.floor(Math.random() * arr.length)]
const rand = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min
const uuid = () => randomUUID()
const pastDate = (daysBack) => {
  const d = new Date()
  d.setDate(d.getDate() - daysBack)
  return d.toISOString()
}
const futureDate = (daysAhead) => {
  const d = new Date()
  d.setDate(d.getDate() + daysAhead)
  return d.toISOString().split('T')[0]
}
const sq = (s) => `'${String(s).replace(/'/g, "''")}'`

// ── Data pools ────────────────────────────────────────────────────────────────

const maleNames = [
  'Arjun Sharma','Rohan Verma','Karan Singh','Amit Patel','Rahul Gupta',
  'Vikram Nair','Siddharth Joshi','Aditya Kumar','Pranav Mishra','Ishaan Tiwari',
  'Ayush Rao','Divyansh Chauhan','Harsh Agarwal','Nikhil Mehta','Shubham Pandey',
  'Aarav Srivastava','Varun Kapoor','Yash Bhatia','Dev Saxena','Kunal Malhotra',
  'Tushar Reddy','Akash Dubey','Gaurav Tripathi','Mohit Bansal','Ritesh Yadav',
  'Suraj Jain','Ankit Bhatt','Abhishek Chaudhary','Deepak Rawat','Lokesh Patil',
  'Manish Garg','Naveen Pillai','Omkar Desai','Parth Thakur','Rajat Kashyap',
  'Sachin Goyal','Tanmay Shah','Ujjwal Dixit','Vinay Murthy','Zaid Khan',
  'Aryan Bose','Chirag Menon','Dhruv Khanna','Farhan Siddiqui','Girish Iyer',
  'Himanshu Tomar','Jai Rathore','Karthik Subramaniam','Lalit Shekhawat','Madhav Jha',
  'Nakul Oberoi','Omkar Kulkarni','Piyush Agarwal','Qasim Ali','Rakesh Yadav',
  'Saurabh Bhardwaj','Tarun Luthra','Uday Pal','Vivek Anand','Waqar Hussain',
]

const femaleNames = [
  'Priya Sharma','Ananya Singh','Neha Verma','Shreya Patel','Pooja Gupta',
  'Aarohi Nair','Diya Joshi','Ishita Kumar','Kavya Mishra','Lakshmi Tiwari',
  'Meera Rao','Nandini Chauhan','Pallavi Agarwal','Riya Mehta','Sneha Pandey',
  'Tanvi Srivastava','Uma Kapoor','Vidhi Bhatia','Swati Saxena','Aditi Malhotra',
  'Bhavna Reddy','Charu Dubey','Dipika Tripathi','Esha Bansal','Fatima Khan',
  'Garima Yadav','Harshi Jain','Isha Bhatt','Jaya Chaudhary','Komal Rawat',
  'Lavanya Menon','Mansi Oberoi','Nisha Kulkarni','Ojasvi Pandey','Payal Jha',
  'Ritika Bose','Shalini Khanna','Trisha Iyer','Urvi Soni','Vandana Mishra',
]

const colleges = [
  'IIT Delhi','IIT Bombay','IIT Madras','IIT Kanpur','IIT Kharagpur',
  'NIT Trichy','NIT Warangal','NIT Surathkal','BITS Pilani','BITS Hyderabad',
  'Delhi University','Mumbai University','Pune University','VIT Vellore','SRM Chennai',
  'Jadavpur University','Anna University','Osmania University','BHU Varanasi','AMU Aligarh',
  'IIIT Hyderabad','IIIT Delhi','Manipal University','Thapar University','LPU Punjab',
]

const trainRoutes = [
  { train: '12301', name: 'Rajdhani Express', src: 'New Delhi', dst: 'Howrah' },
  { train: '12302', name: 'Rajdhani Express', src: 'Howrah', dst: 'New Delhi' },
  { train: '12951', name: 'Mumbai Rajdhani', src: 'New Delhi', dst: 'Mumbai Central' },
  { train: '12952', name: 'Mumbai Rajdhani', src: 'Mumbai Central', dst: 'New Delhi' },
  { train: '12627', name: 'Karnataka Express', src: 'New Delhi', dst: 'Bengaluru' },
  { train: '12628', name: 'Karnataka Express', src: 'Bengaluru', dst: 'New Delhi' },
  { train: '12505', name: 'North East Express', src: 'New Delhi', dst: 'Guwahati' },
  { train: '12506', name: 'North East Express', src: 'Guwahati', dst: 'New Delhi' },
  { train: '22691', name: 'Rajdhani Express', src: 'New Delhi', dst: 'Bengaluru' },
  { train: '12259', name: 'Sealdah Duronto', src: 'New Delhi', dst: 'Kolkata' },
  { train: '12030', name: 'Swarna Shatabdi', src: 'Amritsar', dst: 'New Delhi' },
  { train: '12137', name: 'Punjab Mail', src: 'Firozpur', dst: 'Mumbai' },
  { train: '12001', name: 'Bhopal Shatabdi', src: 'New Delhi', dst: 'Bhopal' },
  { train: '12049', name: 'Gatimaan Express', src: 'Hazrat Nizamuddin', dst: 'Agra' },
  { train: '12650', name: 'Karnataka Sampark', src: 'Hazrat Nizamuddin', dst: 'Bengaluru' },
]

const flightRoutes = [
  { flight: 'AI202', src: 'New Delhi', dst: 'Mumbai' },
  { flight: 'AI203', src: 'Mumbai', dst: 'New Delhi' },
  { flight: '6E341', src: 'New Delhi', dst: 'Bengaluru' },
  { flight: '6E342', src: 'Bengaluru', dst: 'New Delhi' },
  { flight: 'SG401', src: 'New Delhi', dst: 'Hyderabad' },
  { flight: 'UK895', src: 'Mumbai', dst: 'Kolkata' },
  { flight: 'AI440', src: 'Kolkata', dst: 'Bengaluru' },
  { flight: '6E211', src: 'Chennai', dst: 'New Delhi' },
  { flight: 'SG702', src: 'New Delhi', dst: 'Guwahati' },
  { flight: 'AI892', src: 'Mumbai', dst: 'Goa' },
]

const chatMessages = [
  'Hey everyone! Anyone need help with luggage?',
  'Which coach are you all in?',
  'Anyone up for dinner together? There is a good dhaba at the next stop.',
  'The train is running 30 min late btw',
  'Anyone from Delhi NCR here?',
  'Has anyone booked a cab from the station?',
  'We can share a cab if you are going towards the same direction',
  'What time does this reach the destination?',
  'Is the AC working in S4? Feels warm',
  'Anyone want to play cards?',
  'There is a nice sunset view from the left side right now!',
  'Pantry car food is decent today',
  'Hey, are you a BITS student?',
  'Same batch! Which branch?',
  'Anyone else nervous about the semester starting?',
  'Just joined this group, hi everyone 👋',
  'The platform number is 4, confirmed on the app',
  'Will we reach on time or is there a delay?',
  'Anyone need a phone charger? I have a multi-port',
  'Great trip so far, met some awesome people here!',
  'Do not forget to check your PNR status',
  'I have extra snacks if anyone wants',
  'The WiFi here is surprisingly good',
  'Which hostel are you in?',
  'First time traveling alone, this group is a lifesaver!',
  'Anyone doing their internship in Bangalore?',
  'We should plan a meetup once we reach!',
  'Confirmed — upper berth in coach B4',
  'Just saw a peacock from the window 😂',
  'Can someone save a seat? BRB getting water',
]

const groupNames = [
  ['Night Owls 🦉', 'For those traveling overnight — let\'s make it fun'],
  ['Girls Squad ✨', 'Safe space for girls to connect and coordinate'],
  ['Boys Only 🚀', 'Just the guys, no filter'],
  ['IIT Gang 🎓', 'Only IITians, represent!'],
  ['Chill Vibes 😎', 'No drama, just good company'],
  ['Delhi Crew 🏙️', 'All Delhi folks in one place'],
  ['Night Shift ☀️', 'Connecting night travelers'],
  ['Study Group 📚', 'Final year students connect here'],
  ['Foodies 🍱', 'Who wants to share food and find good dhabas'],
  ['Card Players ♠️', 'Anyone up for a game of cards?'],
  ['Cab Sharing 🚕', 'Let\'s split cab fare from the station'],
  ['Music Lovers 🎵', 'AirPods in, vibe together'],
  ['First Timers 🌟', 'First time on this route? Join us!'],
  ['Backpackers 🎒', 'Minimal luggage, maximum experience'],
  ['Alumni Connect 🤝', 'Same college? Let\'s catch up'],
]

// ── Generate data ─────────────────────────────────────────────────────────────

const allNames = [...maleNames, ...femaleNames]
const users = allNames.slice(0, 100).map((name, i) => {
  const isFemale = femaleNames.includes(name)
  const gender = isFemale ? 'female' : 'male'
  const email = name.toLowerCase().replace(/\s+/g, '.') + `${rand(1,99)}@example.com`
  const college = pick(colleges)
  const pnrVerified = Math.random() > 0.5
  const collegeVerified = Math.random() > 0.6
  return {
    id: uuid(),
    email,
    name,
    google_id: `google_mock_${uuid().replace(/-/g,'')}`,
    avatar_url: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(name)}`,
    bio: pick([
      `${college} student, love traveling!`,
      `Final year at ${college}. Always up for a good trip.`,
      `From ${pick(['Delhi','Mumbai','Bangalore','Hyderabad','Kolkata'])}. ${college} grad.`,
      `${college} | ${pick(['CSE','ECE','ME','Civil','Chemical'])} | Batch ${rand(2020,2026)}`,
      null,
    ]),
    gender,
    college_name: college,
    college_verified: collegeVerified,
    pnr_verified: pnrVerified,
  }
})

// Assign users to train/flight routes creating rooms
const roomAssignments = [] // { route, date, userIds[] }
const allRoutes = [
  ...trainRoutes.map(r => ({ ...r, type: 'train' })),
  ...flightRoutes.map(r => ({ ...r, type: 'flight' })),
]

// Create ~25 rooms across future dates
const rooms = []
const journeys = []
const roomMembers = []
let userIdx = 0

for (let ri = 0; ri < allRoutes.length && userIdx < users.length; ri++) {
  const route = allRoutes[ri % allRoutes.length]
  const daysAhead = rand(1, 30)
  const journeyDate = futureDate(daysAhead)
  const roomKey = route.type === 'train'
    ? `train_${route.train}_${journeyDate}`
    : `flight_${route.flight}_${journeyDate}`

  const roomId = uuid()
  const memberCount = rand(3, 8)
  const roomUserIds = []

  for (let mi = 0; mi < memberCount && userIdx < users.length; mi++, userIdx++) {
    const user = users[userIdx]
    const journeyId = uuid()

    journeys.push({
      id: journeyId,
      user_id: user.id,
      journey_type: route.type,
      train_number: route.train ?? null,
      flight_number: route.flight ?? null,
      source: route.src,
      destination: route.dst,
      journey_date: journeyDate,
    })

    roomUserIds.push({ userId: user.id, journeyId })
  }

  rooms.push({
    id: roomId,
    room_key: roomKey,
    room_type: route.type,
    identifier: route.train ?? route.flight,
    source: route.src,
    destination: route.dst,
    journey_date: journeyDate,
    member_count: roomUserIds.length,
  })

  roomUserIds.forEach(({ userId, journeyId }) => {
    roomMembers.push({ id: uuid(), room_id: roomId, user_id: userId, journey_id: journeyId })
  })
}

// Create groups (1-2 per room)
const groups = []
const groupMembers = []
const messages = []

rooms.forEach((room, ri) => {
  const membersInRoom = roomMembers.filter(m => m.room_id === room.id)
  if (membersInRoom.length < 2) return

  const numGroups = rand(1, 2)
  for (let gi = 0; gi < numGroups; gi++) {
    const [gname, gdesc] = groupNames[(ri * 2 + gi) % groupNames.length]
    const creatorMember = membersInRoom[0]
    const genderFilter = pick(['any','any','all_girls','all_boys','mixed'])
    const maxMembers = rand(5, 15)
    const requiresApproval = Math.random() > 0.6
    const groupId = uuid()
    const groupMemberCount = Math.min(rand(2, membersInRoom.length), maxMembers)

    groups.push({
      id: groupId,
      room_id: room.id,
      creator_id: creatorMember.user_id,
      name: gname,
      description: gdesc,
      gender_filter: genderFilter,
      max_members: maxMembers,
      visibility: Math.random() > 0.3 ? 'public' : 'private',
      requires_approval: requiresApproval,
      member_count: groupMemberCount,
    })

    // Add members to group
    membersInRoom.slice(0, groupMemberCount).forEach((rm, mIdx) => {
      groupMembers.push({
        id: uuid(),
        group_id: groupId,
        user_id: rm.user_id,
        status: 'approved',
        approved_at: pastDate(rand(1,5)),
        approved_by: creatorMember.user_id,
      })
    })

    // Generate room chat messages
    const roomChatCount = rand(8, 18)
    const roomUserList = membersInRoom.map(m => m.user_id)
    for (let i = 0; i < roomChatCount; i++) {
      const createdAt = pastDate(rand(0, 3))
      messages.push({
        id: uuid(),
        room_id: room.id,
        group_id: null,
        sender_id: pick(roomUserList),
        content: pick(chatMessages),
        message_type: 'text',
        created_at: new Date(Date.now() - rand(0, 72*60*60*1000)).toISOString(),
      })
    }

    // Generate group chat messages
    const groupUserList = membersInRoom.slice(0, groupMemberCount).map(m => m.user_id)
    const groupChatCount = rand(5, 12)
    for (let i = 0; i < groupChatCount; i++) {
      messages.push({
        id: uuid(),
        room_id: null,
        group_id: groupId,
        sender_id: pick(groupUserList),
        content: pick(chatMessages),
        message_type: 'text',
        created_at: new Date(Date.now() - rand(0, 48*60*60*1000)).toISOString(),
      })
    }
  }
})

// ── Emit SQL ──────────────────────────────────────────────────────────────────

const lines = []

lines.push(`-- SafarMate seed data — generated ${new Date().toISOString()}`)
lines.push(`-- ${users.length} users · ${rooms.length} rooms · ${groups.length} groups · ${messages.length} messages`)
lines.push('')

// Users
lines.push('-- ── Users ──────────────────────────────────────────────────────────────')
lines.push('INSERT INTO public.users (id,email,name,google_id,avatar_url,bio,gender,college_name,college_verified,pnr_verified) VALUES')
lines.push(users.map(u =>
  `(${sq(u.id)},${sq(u.email)},${sq(u.name)},${sq(u.google_id)},${sq(u.avatar_url)},${u.bio ? sq(u.bio) : 'NULL'},${sq(u.gender)},${sq(u.college_name)},${u.college_verified},${u.pnr_verified})`
).join(',\n') + ';')
lines.push('')

// Rooms
lines.push('-- ── Rooms ──────────────────────────────────────────────────────────────')
lines.push('INSERT INTO public.rooms (id,room_key,room_type,identifier,source,destination,journey_date,member_count) VALUES')
lines.push(rooms.map(r =>
  `(${sq(r.id)},${sq(r.room_key)},${sq(r.room_type)},${r.identifier ? sq(r.identifier) : 'NULL'},${sq(r.source)},${sq(r.destination)},${sq(r.journey_date)},${r.member_count})`
).join(',\n') + ';')
lines.push('')

// Journeys
lines.push('-- ── Journeys ────────────────────────────────────────────────────────────')
lines.push('INSERT INTO public.journeys (id,user_id,journey_type,train_number,flight_number,source,destination,journey_date) VALUES')
lines.push(journeys.map(j =>
  `(${sq(j.id)},${sq(j.user_id)},${sq(j.journey_type)},${j.train_number ? sq(j.train_number) : 'NULL'},${j.flight_number ? sq(j.flight_number) : 'NULL'},${sq(j.source)},${sq(j.destination)},${sq(j.journey_date)})`
).join(',\n') + ';')
lines.push('')

// Room members
lines.push('-- ── Room Members ────────────────────────────────────────────────────────')
lines.push('INSERT INTO public.room_members (id,room_id,user_id,journey_id) VALUES')
lines.push(roomMembers.map(m =>
  `(${sq(m.id)},${sq(m.room_id)},${sq(m.user_id)},${sq(m.journey_id)})`
).join(',\n') + ';')
lines.push('')

// Groups
lines.push('-- ── Groups ──────────────────────────────────────────────────────────────')
lines.push('INSERT INTO public.groups (id,room_id,creator_id,name,description,gender_filter,max_members,visibility,requires_approval,member_count) VALUES')
lines.push(groups.map(g =>
  `(${sq(g.id)},${sq(g.room_id)},${sq(g.creator_id)},${sq(g.name)},${sq(g.description)},${sq(g.gender_filter)},${g.max_members},${sq(g.visibility)},${g.requires_approval},${g.member_count})`
).join(',\n') + ';')
lines.push('')

// Group members
lines.push('-- ── Group Members ───────────────────────────────────────────────────────')
lines.push('INSERT INTO public.group_members (id,group_id,user_id,status,approved_at,approved_by) VALUES')
lines.push(groupMembers.map(m =>
  `(${sq(m.id)},${sq(m.group_id)},${sq(m.user_id)},${sq(m.status)},${sq(m.approved_at)},${sq(m.approved_by)})`
).join(',\n') + ';')
lines.push('')

// Messages
lines.push('-- ── Messages ────────────────────────────────────────────────────────────')
lines.push('INSERT INTO public.messages (id,room_id,group_id,sender_id,content,message_type,created_at) VALUES')
lines.push(messages.map(m =>
  `(${sq(m.id)},${m.room_id ? sq(m.room_id) : 'NULL'},${m.group_id ? sq(m.group_id) : 'NULL'},${sq(m.sender_id)},${sq(m.content)},${sq(m.message_type)},${sq(m.created_at)})`
).join(',\n') + ';')
lines.push('')

lines.push('-- Done!')

const output = lines.join('\n')
writeFileSync('/home/anya/Desktop/SafarMate/supabase/migrations/002_seed.sql', output)
console.log(`Generated:`)
console.log(`  ${users.length} users`)
console.log(`  ${rooms.length} rooms`)
console.log(`  ${journeys.length} journeys`)
console.log(`  ${roomMembers.length} room memberships`)
console.log(`  ${groups.length} groups`)
console.log(`  ${groupMembers.length} group memberships`)
console.log(`  ${messages.length} messages`)
console.log(`\nOutput: supabase/migrations/002_seed.sql`)
