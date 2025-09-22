using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ASession.Data;
using ASession.Models;

namespace ASession.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TeamsController : ControllerBase
    {
        private readonly ASessionDbContext _context;

        public TeamsController(ASessionDbContext context)
        {
            _context = context;
        }

        // GET: api/Teams
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Team>>> GetTeams()
        {
            return await _context.Teams
                .Include(t => t.TeamMembers)
                .ThenInclude(tm => tm.User)
                .ToListAsync();
        }

        // GET: api/Teams/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Team>> GetTeam(int id)
        {
            var team = await _context.Teams
                .Include(t => t.TeamMembers)
                .ThenInclude(tm => tm.User)
                .Include(t => t.SheetMusics)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (team == null)
            {
                return NotFound();
            }

            return team;
        }

        // POST: api/Teams
        [HttpPost]
        public async Task<ActionResult<Team>> PostTeam(Team team)
        {
            team.CreatedAt = DateTime.UtcNow;
            team.UpdatedAt = DateTime.UtcNow;
            _context.Teams.Add(team);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetTeam", new { id = team.Id }, team);
        }

        // PUT: api/Teams/5
        [HttpPut("{id}")]
        public async Task<IActionResult> PutTeam(int id, Team team)
        {
            if (id != team.Id)
            {
                return BadRequest();
            }

            team.UpdatedAt = DateTime.UtcNow;
            _context.Entry(team).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!TeamExists(id))
                {
                    return NotFound();
                }
                else
                {
                    throw;
                }
            }

            return NoContent();
        }

        // DELETE: api/Teams/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteTeam(int id)
        {
            var team = await _context.Teams.FindAsync(id);
            if (team == null)
            {
                return NotFound();
            }

            _context.Teams.Remove(team);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        // POST: api/Teams/5/members
        [HttpPost("{id}/members")]
        public async Task<ActionResult<TeamMember>> AddTeamMember(int id, [FromBody] int userId)
        {
            var team = await _context.Teams.FindAsync(id);
            if (team == null)
            {
                return NotFound("Team not found");
            }

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                return NotFound("User not found");
            }

            // Check if user is already a member
            var existingMember = await _context.TeamMembers
                .FirstOrDefaultAsync(tm => tm.TeamId == id && tm.UserId == userId);
            
            if (existingMember != null)
            {
                return BadRequest("User is already a member of this team");
            }

            var teamMember = new TeamMember
            {
                TeamId = id,
                UserId = userId,
                JoinedAt = DateTime.UtcNow
            };

            _context.TeamMembers.Add(teamMember);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetTeam", new { id = team.Id }, teamMember);
        }

        private bool TeamExists(int id)
        {
            return _context.Teams.Any(e => e.Id == id);
        }
    }
}