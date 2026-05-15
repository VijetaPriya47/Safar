/**
 * Pushes generated seed data directly to Supabase via REST API (service role).
 * Run AFTER the schema migration has been applied in the SQL editor.
 *
 * Usage:  node scripts/seed-rest.mjs
 */

import { randomUUID } from 'crypto'

const SUPABASE_URL = process.env.SUPABASE_URL
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars.')
  console.error('Run from the repo root: cd apps/api && node --env-file=.env ../../scripts/seed-rest.mjs')
  process.exit(1)
}

const headers = {
  'apikey': SERVICE_KEY,
  'Authorization': `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
  'Prefer': 'return=minimal,resolution=ignore-duplicates',
}

async function insert(table, rows, chunkSize = 50) {
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize)
    const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
      method: 'POST', headers, body: JSON.stringify(chunk),
    })
    if (!res.ok) {
      const err = await res.text()
      throw new Error(`Failed inserting into ${table}: ${err}`)
    }
  }
  console.log(`  ✓ ${rows.length} rows → ${table}`)
}

// ── Data pools ────────────────────────────────────────────────────────────────

const pick = (arr) => arr[Math.floor(Math.random() * arr.length)]
const rand = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min
const uuid = () => randomUUID()

const futureDate = (daysAhead) => {
  const d = new Date(); d.setDate(d.getDate() + daysAhead)
  return d.toISOString().split('T')[0]
}

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
  'Nakul Oberoi','Omkar Kulkarni','Piyush Agarwal','Rakesh Yadav','Saurabh Bhardwaj',
  'Tarun Luthra','Uday Pal','Vivek Anand','Yuvraj Chauhan','Zeeshan Khan',
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

const bios = (name, college) => pick([
  `${college} student. Always up for a good trip!`,
  `Final year at ${college}. Love meeting new people.`,
  `${college} | Batch ${rand(2021,2026)} | Travelling light.`,
  `From ${pick(['Delhi','Mumbai','Bangalore','Hyderabad','Kolkata'])} studying at ${college}.`,
  null,
])

const trainRoutes = [
  { train: '12301', src: 'New Delhi',            dst: 'Howrah'          },
  { train: '12951', src: 'New Delhi',            dst: 'Mumbai Central'  },
  { train: '12627', src: 'New Delhi',            dst: 'Bengaluru'       },
  { train: '12505', src: 'New Delhi',            dst: 'Guwahati'        },
  { train: '22691', src: 'New Delhi',            dst: 'Bengaluru'       },
  { train: '12259', src: 'New Delhi',            dst: 'Kolkata'         },
  { train: '12030', src: 'Amritsar',             dst: 'New Delhi'       },
  { train: '12001', src: 'New Delhi',            dst: 'Bhopal'          },
  { train: '12049', src: 'Hazrat Nizamuddin',    dst: 'Agra'            },
  { train: '12650', src: 'Hazrat Nizamuddin',    dst: 'Bengaluru'       },
  { train: '12137', src: 'Firozpur',             dst: 'Mumbai'          },
  { train: '12302', src: 'Howrah',               dst: 'New Delhi'       },
  { train: '12952', src: 'Mumbai Central',       dst: 'New Delhi'       },
  { train: '12506', src: 'Guwahati',             dst: 'New Delhi'       },
  { train: '12628', src: 'Bengaluru',            dst: 'New Delhi'       },
]

const flightRoutes = [
  { flight: 'AI202',  src: 'New Delhi',  dst: 'Mumbai'    },
  { flight: '6E341',  src: 'New Delhi',  dst: 'Bengaluru' },
  { flight: 'SG401',  src: 'New Delhi',  dst: 'Hyderabad' },
  { flight: 'UK895',  src: 'Mumbai',     dst: 'Kolkata'   },
  { flight: 'AI440',  src: 'Kolkata',    dst: 'Bengaluru' },
]

const chatPool = [
  'Hey everyone! Which coach are you in?',
  'Anyone need help with luggage at the station?',
  'The train is running 30 min late btw',
  'Anyone from Delhi NCR here?',
  'Has anyone booked a cab from the station?',
  'We can share a cab if going the same way',
  'What time does this reach the destination?',
  'Is the AC working in S4? Feels warm in here',
  'Anyone want to play cards?',
  'Pantry car food is decent today',
  'Hey, are you a BITS student?',
  'Same batch! Which branch are you in?',
  'Just joined this group, hi everyone!',
  'Platform number is 4, confirmed on the app',
  'Will we reach on time or is there a delay?',
  'I have a multi-port charger if anyone needs it',
  'Great trip so far, met some awesome people!',
  'Do not forget to check your PNR status',
  'I have extra snacks if anyone wants some',
  'Which hostel are you staying in?',
  'First time traveling alone, this group helps a lot!',
  'Anyone doing internship in Bangalore this summer?',
  'We should plan a meetup once we reach!',
  'Just saw a peacock from the window lol',
  'Can someone save a seat? BRB getting water',
  'Upper berth in B4 confirmed',
  'The WiFi here is surprisingly good',
  'Anyone else nervous about the semester starting?',
  'There is a nice sunset view from the left side!',
  'Nice to meet everyone here, safe travels!',
]

const groupDefs = [
  { name: 'Night Owls', desc: 'For overnight travelers, making the journey fun', gf: 'any' },
  { name: 'Girls Squad', desc: 'Safe space for girls to connect and coordinate', gf: 'all_girls' },
  { name: 'Boys Crew', desc: 'Just the guys', gf: 'all_boys' },
  { name: 'IIT Gang', desc: 'IITians only, lets represent!', gf: 'any' },
  { name: 'Chill Vibes', desc: 'No drama, just good company', gf: 'mixed' },
  { name: 'Delhi Crew', desc: 'All Delhi folks in one place', gf: 'any' },
  { name: 'Cab Sharing', desc: 'Split cab fare from the station', gf: 'any' },
  { name: 'Foodies', desc: 'Find good dhabas and share food', gf: 'any' },
  { name: 'Card Players', desc: 'Anyone up for a game?', gf: 'any' },
  { name: 'First Timers', desc: 'First time on this route? Join us!', gf: 'any' },
  { name: 'Study Group', desc: 'Final year students, connect here', gf: 'any' },
  { name: 'Alumni Connect', desc: 'Same college? Lets catch up!', gf: 'any' },
]

// ── Build data ────────────────────────────────────────────────────────────────

const allNames = [...maleNames, ...femaleNames].slice(0, 100)
const users = allNames.map((name, i) => {
  const isFemale = femaleNames.includes(name)
  const college = pick(colleges)
  return {
    id: uuid(),
    email: `${name.toLowerCase().replace(/\s+/g,'.')}${rand(1,99)}@example.com`,
    name,
    google_id: `mock_${uuid().replace(/-/g,'')}`,
    avatar_url: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(name)}`,
    bio: bios(name, college),
    gender: isFemale ? 'female' : 'male',
    college_name: college,
    college_verified: Math.random() > 0.5,
    pnr_verified: Math.random() > 0.4,
  }
})

const allRoutes = [
  ...trainRoutes.map(r => ({ ...r, type: 'train' })),
  ...flightRoutes.map(r => ({ ...r, type: 'flight' })),
]

const rooms = [], journeys = [], roomMembers = [], groups = [], groupMembers = [], messages = []
let userCursor = 0

allRoutes.forEach((route, ri) => {
  if (userCursor >= users.length) return
  const journeyDate = futureDate(rand(1, 30))
  const roomKey = route.type === 'train'
    ? `train_${route.train}_${journeyDate}`
    : `flight_${route.flight}_${journeyDate}`
  const roomId = uuid()
  const count = rand(3, 7)
  const roomUsers = []

  for (let m = 0; m < count && userCursor < users.length; m++, userCursor++) {
    const u = users[userCursor]
    const jId = uuid()
    journeys.push({
      id: jId, user_id: u.id, journey_type: route.type,
      train_number: route.train ?? null, flight_number: route.flight ?? null,
      source: route.src, destination: route.dst, journey_date: journeyDate,
    })
    roomUsers.push({ userId: u.id, journeyId: jId })
  }

  rooms.push({
    id: roomId, room_key: roomKey, room_type: route.type,
    identifier: route.train ?? route.flight ?? null,
    source: route.src, destination: route.dst,
    journey_date: journeyDate, member_count: roomUsers.length,
  })
  roomUsers.forEach(({ userId, journeyId }) =>
    roomMembers.push({ id: uuid(), room_id: roomId, user_id: userId, journey_id: journeyId })
  )

  // Groups for this room
  const numGroups = rand(1, 2)
  const gDefs = groupDefs.slice((ri * 2) % groupDefs.length, (ri * 2) % groupDefs.length + numGroups)
  gDefs.forEach((gd, gi) => {
    if (roomUsers.length < 2) return
    const groupId = uuid()
    const maxM = rand(5, 12)
    const creatorId = roomUsers[0].userId
    const gMembers = roomUsers.slice(0, Math.min(rand(2, roomUsers.length), maxM))
    const requiresApproval = Math.random() > 0.6

    groups.push({
      id: groupId, room_id: roomId, creator_id: creatorId,
      name: gd.name, description: gd.desc, gender_filter: gd.gf,
      max_members: maxM, visibility: Math.random() > 0.3 ? 'public' : 'private',
      requires_approval: requiresApproval, member_count: gMembers.length,
    })

    const now = new Date().toISOString()
    gMembers.forEach(m => groupMembers.push({
      id: uuid(), group_id: groupId, user_id: m.userId,
      status: 'approved', approved_at: now, approved_by: creatorId,
    }))

    // Room chat
    const roomUserIds = roomUsers.map(u => u.userId)
    for (let i = 0; i < rand(8, 16); i++) {
      messages.push({
        id: uuid(), room_id: roomId, group_id: null,
        sender_id: pick(roomUserIds), content: pick(chatPool),
        message_type: 'text',
        created_at: new Date(Date.now() - rand(0, 72*60*60*1000)).toISOString(),
      })
    }

    // Group chat
    const gUserIds = gMembers.map(m => m.userId)
    for (let i = 0; i < rand(5, 10); i++) {
      messages.push({
        id: uuid(), room_id: null, group_id: groupId,
        sender_id: pick(gUserIds), content: pick(chatPool),
        message_type: 'text',
        created_at: new Date(Date.now() - rand(0, 48*60*60*1000)).toISOString(),
      })
    }
  })
})

// ── Push ──────────────────────────────────────────────────────────────────────

console.log('Pushing seed data to Supabase...\n')
console.log(`  ${users.length} users, ${rooms.length} rooms, ${journeys.length} journeys`)
console.log(`  ${groups.length} groups, ${groupMembers.length} group members`)
console.log(`  ${messages.length} messages\n`)

try {
  await insert('users', users)
  await insert('rooms', rooms)
  await insert('journeys', journeys)
  await insert('room_members', roomMembers)
  await insert('groups', groups)
  await insert('group_members', groupMembers)
  await insert('messages', messages)

  console.log('\nAll done! Open the app at http://localhost:3000')
} catch (err) {
  console.error('\nError:', err.message)
  console.error('Make sure you ran the schema migration first (001_init.sql in SQL Editor)')
  process.exit(1)
}
