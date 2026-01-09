using MagicVilla_VillaAPI.Models;
using Microsoft.AspNetCore.Mvc;
using MagicVilla_VillaAPI.Models.Dto;
using MagicVilla_VillaAPI.Data;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.JsonPatch;
using Microsoft.EntityFrameworkCore;
using AutoMapper;
using MagicVilla_VillaAPI.Repositry.IRepositry;
using System.Net;

namespace MagicVilla_VillaAPI.Controllers
{
    //By using the controller name
    [Route("/api/VillaAPI")]

    //by using [controller] it will call the controller class by deafult ||| its not the best practice 
    //[Route("/api/[controller]")]

    [ApiController]
    public class VillaAPIController : ControllerBase
    {


        private readonly IVillaRepositry _dbVilla;
        private readonly IMapper _mapper ;
        protected APIResponse _response;
        public VillaAPIController(IVillaRepositry dbVilla , IMapper mapper)
        {
            _dbVilla= dbVilla;
            _mapper= mapper;
            this._response = new(); 
        }

        //add verb 
        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]

        //create end point data location and make it ienumerable object 
        //public async Task<ActionResult<IEnumerable<VillaDTO>>>  GetVillas()
        public async Task<ActionResult<APIResponse>> GetVillas()
        {
            // return Ok(VillaStore.villaList);
            // villaStore to make it read from on-the-fly db
            // return Ok(await(_db.Villas.ToListAsync()) );   --> without mapper
            
            try
            {
                IEnumerable<Villa> villaList = await _dbVilla.GetAllAsync();
                _response.Result = _mapper.Map<List<VillaDTO>>(villaList);
                _response.StatusCode = HttpStatusCode.OK;
                return Ok(_response);
            }
            catch(Exception ex) { 
                _response.IsSuccess= false;
                _response.ErrorMessage
                    = new List<string> { ex.Message };
            }
            return _response;        }



        [HttpGet("{id:int}", Name = "GetVilla")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]

        // [ProducesResponseType(200 , Type = typeof(VillaDTO)]
        public async Task<ActionResult<APIResponse>> GetVilla(int id)
        {
            try
            {
                if (id == 0)
                {
                    return BadRequest();
                }
                //var villa = VillaStore.villaList.FirstOrDefault(x => x.Id == id);
                var villa = await _dbVilla.GetAsync(x => x.Id == id);


                if (villa == null)
                {
                    return NotFound();
                }

                _response.Result = _mapper.Map<VillaDTO>(villa);
                _response.StatusCode = HttpStatusCode.OK;
                return Ok(_response);
            }
            catch (Exception ex)
            {
                _response.IsSuccess = false;
                _response.ErrorMessage
                    = new List<string> { ex.Message };
            }
            return _response;

        }




        [HttpPost]
        [ProducesResponseType(StatusCodes.Status201Created)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]

        public async Task<ActionResult<APIResponse>> CreateVilla([FromBody] VillaCreateDTO createDTO)
        {
            try
            {
                if (await _dbVilla.GetAsync(u => u.Name.ToLower() == createDTO.Name.ToLower()) != null)
                {
                    ModelState.AddModelError("", "Already Exists !");
                    return BadRequest(ModelState);
                    //validation errors that need to be returned to the client.
                    /*By passing ModelState to the BadRequest method, you are returning an HTTP 400 Bad Request
                    response to the client, along with a list of validation errors contained in the ModelState object.*/
                }
                if (createDTO == null)
                {
                    return BadRequest(createDTO);
                }
                //if (villaDTO.Id > 0)
                //{
                //    return StatusCode(StatusCodes.Status500InternalServerError);
                //}
                //villaDTO.Id = _db.Villas.OrderByDescending(x => x.Id).FirstOrDefault().Id + 1;

                //VillaStore.villaList.Add(villaDTO);

                Villa villa = _mapper.Map<Villa>(createDTO);
                //line Villa model = _mapper.Map<Villa>(createDTO); is insted of the following piece if code --> 
                //Villa model = new()
                //{
                //    Name = createDTO.Name,
                //    //Id = villaDTO.Id,
                //    ImageUrl = createDTO.ImageUrl,
                //    Location = createDTO.Location,
                //    sqft = createDTO.sqft,
                //    Rate = createDTO.Rate,
                //    Details = createDTO.Details,
                //    CreatedDate = createDTO.CreatedDate,
                //    UpdatedDate = createDTO.UpdatedDate,
                //};

                await _dbVilla.CreateAsync(villa);

                _response.Result = _mapper.Map<VillaDTO>(villa);
                _response.StatusCode = HttpStatusCode.Created;

                return CreatedAtRoute("GetVilla", new { id = villa.Id }, villa);
            }
            catch (Exception ex)
            {
                _response.IsSuccess = false;
                _response.ErrorMessage
                    = new List<string> { ex.Message };
            }
            return _response;
        }




        [HttpDelete("{id:int}", Name = "DeleteVilla")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]

        public async Task<ActionResult<APIResponse>>  DeleteVilla(int id)
        // ActionResult determine the type of return or what to return
        // IActionResult there is nothing to return 
        {
            try
            {
                if (id == 0)
                {
                    return BadRequest();
                }
                var villa = await _dbVilla.GetAsync(u => u.Id == id);
                if (villa == null)
                {
                    return NotFound();
                }
                await _dbVilla.RemoveAsync(villa);

                _response.StatusCode = HttpStatusCode.NoContent;
                _response.IsSuccess = true;

                return Ok(_response);
            }
            catch (Exception ex)
            {
                _response.IsSuccess = false;
                _response.ErrorMessage
                    = new List<string> { ex.Message };
            }
            return _response;
        }



        [HttpPut("{id}", Name = "UpdateVilla")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<APIResponse>> UpdateVilla(int id, [FromBody] VillaUpdateDTO updateDTO)
        {
            try
            {
                if (updateDTO == null || id != updateDTO.Id)
                {
                    return BadRequest();
                }
                Villa villa = _mapper.Map<Villa>(updateDTO);

                await _dbVilla.UpdateAsync(villa);
                //await _dbVilla.SaveAsync();


                _response.StatusCode = HttpStatusCode.NoContent;
                _response.IsSuccess = true;

                return Ok(_response);
            }
            catch (Exception ex)
            {
                _response.IsSuccess = false;
                _response.ErrorMessage
                    = new List<string> { ex.Message };
            }
            return _response;
        }



        [HttpPatch("id" , Name = "PatchVilla")]
        [ProducesResponseType(StatusCodes.Status204NoContent)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]

        public async Task<ActionResult<APIResponse>>  PatchVilla (int id , JsonPatchDocument<VillaUpdateDTO> patchDto ) //called it patchDto
            //patchDto is a json patch document
        {
            try
            {
                if (patchDto == null || id == 0)
                {
                    return BadRequest();
                }
                var villa = await _dbVilla.GetAsync(x => x.Id == id);


                VillaUpdateDTO villaDTO = _mapper.Map<VillaUpdateDTO>(villa);

                if (villa == null)
                {
                    return BadRequest();
                }
                patchDto.ApplyTo(villaDTO, ModelState);
                // scince it an json patch document we can use apply to and apply the things in that in villa object
                //we use Model state to noyify that if there is and edit apply that to the object 
                if (!ModelState.IsValid)
                {
                    return BadRequest(ModelState);
                }

                Villa model = _mapper.Map<Villa>(villaDTO);

                await _dbVilla.UpdateAsync(model);

                _response.Result = model;
                _response.StatusCode = HttpStatusCode.NoContent;

                return Ok(_response);
            }
            catch (Exception ex)
            {
                _response.IsSuccess = false;
                _response.ErrorMessage
                    = new List<string> { ex.Message };
            }
            return _response;


        }



    }
}
