using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ASession.Data;
using ASession.Models;

namespace ASession.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SheetMusicController : ControllerBase
    {
        private readonly ASessionDbContext _context;

        public SheetMusicController(ASessionDbContext context)
        {
            _context = context;
        }

        // GET: api/SheetMusic
        [HttpGet]
        public async Task<ActionResult<IEnumerable<SheetMusic>>> GetSheetMusics()
        {
            return await _context.SheetMusics
                .Include(sm => sm.Team)
                .Include(sm => sm.CreatedByUser)
                .Include(sm => sm.MidiFiles)
                .ToListAsync();
        }

        // GET: api/SheetMusic/team/5
        [HttpGet("team/{teamId}")]
        public async Task<ActionResult<IEnumerable<SheetMusic>>> GetSheetMusicsByTeam(int teamId)
        {
            return await _context.SheetMusics
                .Where(sm => sm.TeamId == teamId)
                .Include(sm => sm.CreatedByUser)
                .Include(sm => sm.MidiFiles)
                .ToListAsync();
        }

        // GET: api/SheetMusic/5
        [HttpGet("{id}")]
        public async Task<ActionResult<SheetMusic>> GetSheetMusic(int id)
        {
            var sheetMusic = await _context.SheetMusics
                .Include(sm => sm.Team)
                .Include(sm => sm.CreatedByUser)
                .Include(sm => sm.MidiFiles)
                .FirstOrDefaultAsync(sm => sm.Id == id);

            if (sheetMusic == null)
            {
                return NotFound();
            }

            return sheetMusic;
        }

        // POST: api/SheetMusic
        [HttpPost]
        public async Task<ActionResult<SheetMusic>> PostSheetMusic(SheetMusic sheetMusic)
        {
            sheetMusic.CreatedAt = DateTime.UtcNow;
            sheetMusic.UpdatedAt = DateTime.UtcNow;
            _context.SheetMusics.Add(sheetMusic);
            await _context.SaveChangesAsync();

            return CreatedAtAction("GetSheetMusic", new { id = sheetMusic.Id }, sheetMusic);
        }

        // PUT: api/SheetMusic/5
        [HttpPut("{id}")]
        public async Task<IActionResult> PutSheetMusic(int id, SheetMusic sheetMusic)
        {
            if (id != sheetMusic.Id)
            {
                return BadRequest();
            }

            sheetMusic.UpdatedAt = DateTime.UtcNow;
            _context.Entry(sheetMusic).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!SheetMusicExists(id))
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

        // DELETE: api/SheetMusic/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteSheetMusic(int id)
        {
            var sheetMusic = await _context.SheetMusics.FindAsync(id);
            if (sheetMusic == null)
            {
                return NotFound();
            }

            _context.SheetMusics.Remove(sheetMusic);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private bool SheetMusicExists(int id)
        {
            return _context.SheetMusics.Any(e => e.Id == id);
        }
    }
}
